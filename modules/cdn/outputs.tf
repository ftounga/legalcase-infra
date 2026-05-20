output "distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.documents.id
}

output "distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.documents.arn
}

output "distribution_domain_name" {
  description = "CloudFront domain name (e.g. dxxxxx.cloudfront.net) to use as base URL for documents"
  value       = aws_cloudfront_distribution.documents.domain_name
}

output "oac_id" {
  description = "ID of the Origin Access Control"
  value       = aws_cloudfront_origin_access_control.documents.id
}
