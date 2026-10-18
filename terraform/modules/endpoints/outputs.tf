output "endpoint_ids" {
  description = "Interface VPC Endpoint IDs"

  value = {
    for service, endpoint in aws_vpc_endpoint.interface :
    service => endpoint.id
  }
}
