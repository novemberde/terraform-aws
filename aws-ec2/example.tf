variable "ami" {
  description = "the AMI to use"  
}

/* A multi
   line comment. */ 
resource "aws_instance" "web" {
  ami               = "${var.ami}" 
  instance_type     = "t2.micro"
  count             = 1
  source_dest_check = false
#   description = <<EOF
#   ...
#   ...
#   EOF

  connection {
    user = "root"
  }
}