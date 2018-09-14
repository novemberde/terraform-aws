resource "aws_s3_bucket" "novemberde-terraform-states" {
  bucket = "novemberde-terraform-states"
  acl    = "private"
}