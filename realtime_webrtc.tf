locals {
  # The two hosts the task itself reaches out to, read from the URIs it is configured with: it
  # queries the STUN server for the public address it advertises, and relays through the TURN
  # server when one is set. The port is optional in both URI forms and its default differs between
  # the plain and the TLS scheme; TURN also carries its transport as a query parameter.
  realtime_webrtc_stun_port = try(
    tonumber(regex(":(\\d+)(?:\\?|$)", var.realtime_webrtc_stun_server)[0]),
    startswith(var.realtime_webrtc_stun_server, "stuns:") ? 5349 : 3478
  )
  realtime_webrtc_turn_port = try(
    tonumber(regex(":(\\d+)(?:\\?|$)", var.realtime_webrtc_turn_server)[0]),
    startswith(coalesce(var.realtime_webrtc_turn_server, "turn:"), "turns:") ? 5349 : 3478
  )
  realtime_webrtc_turn_protocol = try(regex("transport=(udp|tcp)", var.realtime_webrtc_turn_server)[0], "udp")

  # Neither host's address is known at plan time -- both are the operator's own URIs, resolved by
  # the task -- so each is opened on its single port rather than to a CIDR that cannot be named.
  realtime_webrtc_out_of_band_egress = var.realtime_webrtc_media_enabled ? merge(
    {
      "WebRTC STUN address discovery" = { protocol = "udp", port = local.realtime_webrtc_stun_port }
    },
    var.realtime_webrtc_turn_server == null ? {} : {
      "WebRTC TURN relay" = { protocol = local.realtime_webrtc_turn_protocol, port = local.realtime_webrtc_turn_port }
    },
  ) : {}

  # The same flows again for the application subnets' network ACL, which the VPC module writes and
  # which carries TCP only until asked otherwise. An ACL is stateless and is evaluated before a
  # security group, so without these entries the media is dropped whatever the rules below allow;
  # the VPC module adds each entry's reply direction on the ephemeral range itself.
  realtime_webrtc_nacl_ingress = var.realtime_webrtc_media_enabled ? {
    "webrtc-media" = {
      from_port = var.realtime_webrtc_udp_port_range.from
      to_port   = var.realtime_webrtc_udp_port_range.to
      protocol  = "udp"
    }
  } : {}

  realtime_webrtc_nacl_egress = {
    for name, flow in local.realtime_webrtc_out_of_band_egress :
    name => { from_port = flow.port, protocol = flow.protocol }
  }
}

/*
Realtime API WebRTC media mode (opt-in)

WebRTC media is inbound UDP on OS-assigned ephemeral ports, negotiated
directly to the task that answered the SDP offer: no load balancer can carry
it. This mode therefore gives the task a public IP (through the existing
public-subnet path, which is why nat_gateways_allowed must be false), opens
the media port range and the flows the task itself opens on its own security
group, and pins the service to one task, because calls live in the answering
task's memory and the media path cannot drain.

A security group is only half of the path, so the mode also opens the same
flows on the application subnets' network ACL. That ACL only belongs to this
module when it created the VPC: a deployment on operator-supplied subnet_ids
has to carry the UDP range there itself.
*/

# Fails the plan when the mode is combined with settings that would silently
# break it: a validation surface, holding no infrastructure.
resource "terraform_data" "realtime_webrtc_media_validation" {
  count = var.realtime_webrtc_media_enabled ? 1 : 0

  lifecycle {
    precondition {
      condition     = !var.nat_gateways_allowed
      error_message = "realtime_webrtc_media_enabled requires nat_gateways_allowed = false: behind a NAT gateway the task has no public address, so the SDP answer advertises candidates no caller can reach and every call connects silently dead."
    }
    precondition {
      condition     = var.autoscaling_min_capacity == 1 && var.autoscaling_max_capacity == 1
      error_message = "realtime_webrtc_media_enabled requires autoscaling_min_capacity = 1 and autoscaling_max_capacity = 1: a call lives in the memory of the task that answered its SDP offer, and hangup, the sideband WebSocket and the media itself cannot reach any other task."
    }
    precondition {
      condition     = (var.realtime_webrtc_turn_server == null) == (var.realtime_webrtc_turn_username == null) && (var.realtime_webrtc_turn_server == null) == (var.realtime_webrtc_turn_password == null)
      error_message = "realtime_webrtc_turn_server, realtime_webrtc_turn_username and realtime_webrtc_turn_password are required together."
    }
    # The public task IP the mode needs puts the application subnets on the internet
    # gateway, and an interface endpoint has no private subnet left to live in there.
    precondition {
      condition     = !var.compliance_vpc_endpoints_enabled && !var.guardduty_vpc_endpoint_enabled
      error_message = "realtime_webrtc_media_enabled cannot be combined with compliance_vpc_endpoints_enabled or guardduty_vpc_endpoint_enabled: the media path gives the task a public address, which makes the application subnets public, and an interface VPC endpoint needs a private subnet to place its network interface in. Enabling both would destroy those endpoints without saying so. Turn one of the two off."
    }
  }
}

resource "aws_vpc_security_group_ingress_rule" "realtime_webrtc_media_ipv4" {
  for_each          = var.realtime_webrtc_media_enabled ? toset(var.realtime_webrtc_ingress_ipv4_cidrs) : []
  security_group_id = module.server.security_group_id
  description       = "WebRTC call media (SRTP over UDP)"
  ip_protocol       = "udp"
  from_port         = var.realtime_webrtc_udp_port_range.from
  to_port           = var.realtime_webrtc_udp_port_range.to
  cidr_ipv4         = each.value
  tags              = local.apn_tags

  depends_on = [terraform_data.realtime_webrtc_media_validation]
}

resource "aws_vpc_security_group_ingress_rule" "realtime_webrtc_media_ipv6" {
  for_each          = var.realtime_webrtc_media_enabled && module.vpc.ipv6_enabled ? toset(var.realtime_webrtc_ingress_ipv6_cidrs) : []
  security_group_id = module.server.security_group_id
  description       = "WebRTC call media (SRTP over UDP)"
  ip_protocol       = "udp"
  from_port         = var.realtime_webrtc_udp_port_range.from
  to_port           = var.realtime_webrtc_udp_port_range.to
  cidr_ipv6         = each.value
  tags              = local.apn_tags

  depends_on = [terraform_data.realtime_webrtc_media_validation]
}

# A security group is stateful only for a flow something else opened, and ICE has the task open
# flows of its own: connectivity checks toward every remote candidate, the STUN query that tells it
# what public address to advertise, and the TURN allocation when one is configured. The task's
# security group carries no egress rule at all otherwise, and the VPC module's own passes TCP 443,
# so without these the SDP answer offers only a private address and no call ever connects.
resource "aws_vpc_security_group_egress_rule" "realtime_webrtc_media_ipv4" {
  for_each          = var.realtime_webrtc_media_enabled ? toset(var.realtime_webrtc_ingress_ipv4_cidrs) : []
  security_group_id = module.server.security_group_id
  description       = "WebRTC call media (SRTP over UDP)"
  ip_protocol       = "udp"
  # The destination is the caller's own media port, which its operating system draws from its
  # ephemeral range and never from the range opened for the task, so the range a browser can
  # present is the whole of it. The CIDRs are the callers' networks, as on the ingress side.
  from_port = 1024
  to_port   = 65535
  cidr_ipv4 = each.value
  tags      = local.tags

  depends_on = [terraform_data.realtime_webrtc_media_validation]
}

resource "aws_vpc_security_group_egress_rule" "realtime_webrtc_media_ipv6" {
  for_each          = var.realtime_webrtc_media_enabled && module.vpc.ipv6_enabled ? toset(var.realtime_webrtc_ingress_ipv6_cidrs) : []
  security_group_id = module.server.security_group_id
  description       = "WebRTC call media (SRTP over UDP)"
  ip_protocol       = "udp"
  from_port         = 1024
  to_port           = 65535
  cidr_ipv6         = each.value
  tags              = local.tags

  depends_on = [terraform_data.realtime_webrtc_media_validation]
}

resource "aws_vpc_security_group_egress_rule" "realtime_webrtc_out_of_band_ipv4" {
  for_each          = local.realtime_webrtc_out_of_band_egress
  security_group_id = module.server.security_group_id
  description       = each.key
  ip_protocol       = each.value.protocol
  from_port         = each.value.port
  to_port           = each.value.port
  cidr_ipv4         = "0.0.0.0/0"
  tags              = local.tags

  depends_on = [terraform_data.realtime_webrtc_media_validation]
}

resource "aws_vpc_security_group_egress_rule" "realtime_webrtc_out_of_band_ipv6" {
  for_each          = module.vpc.ipv6_enabled ? local.realtime_webrtc_out_of_band_egress : {}
  security_group_id = module.server.security_group_id
  description       = each.key
  ip_protocol       = each.value.protocol
  from_port         = each.value.port
  to_port           = each.value.port
  cidr_ipv6         = "::/0"
  tags              = local.tags

  depends_on = [terraform_data.realtime_webrtc_media_validation]
}
