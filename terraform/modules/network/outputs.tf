output "vpc_id" {
  description = "作成したVPCのID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public SubnetのID"

  value = {
    for az, subnet in aws_subnet.public :
    az => subnet.id
  }
}

output "private_subnet_ids" {
  description = "Private SubnetのID"

  value = {
    for az, subnet in aws_subnet.private :
    az => subnet.id
  }
}

output "s3_prefix_list_id" {
  description = "S3 Gateway EndpointのプレフィックスリストID"
  value       = aws_vpc_endpoint.s3.prefix_list_id
}
