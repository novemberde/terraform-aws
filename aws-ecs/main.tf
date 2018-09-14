provider "aws" {
  region     = "ap-northeast-2"
}

data "aws_subnet_ids" "public" {
  vpc_id = "${var.vpc_id}"
}

data "aws_subnet" "public" {
  count = "${length(data.aws_subnet_ids.public.ids)}"
  id = "${data.aws_subnet_ids.public.ids[count.index]}"
}

output "subnet_cidr_blocks" {
  value = ["${data.aws_subnet.public.*.cidr_block}"]
}

resource "aws_s3_bucket" "alb_log_bucket" {
  bucket = "${var.alb_log_bucket}"
  acl    = "private"
  policy = <<POLICY
{
  "Id": "Policy",
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::novemberde-alb-logs/*",
      "Principal": {
        "AWS": [
          "*"
        ]
      }
    }
  ]
}
POLICY
}

resource "aws_security_group" "alb-sg" {
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "test_alb" {
  name               = "test-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.alb-sg.id}"]
  subnets            = ["${data.aws_subnet.public.*.id}"]

  # enable_deletion_protection = true

  access_logs {
    bucket  = "${var.alb_log_bucket}"
    prefix  = "alb"
    enabled = true
  }

  tags {
    Environment = "production"
  }
  
}

resource "aws_lb_target_group" "test-tg" {
  name     = "test-tg"
  port     = 80
  protocol = "HTTP"
 
  vpc_id   = "${var.vpc_id}"
}

resource "aws_security_group" "test-ec2-sg" {
  ingress {
    from_port = 3000
    to_port = 3000
    protocol = "tcp"
    security_groups = ["${aws_security_group.alb-sg.id}"]
  }
}

data "aws_ami" "ecs-ami" {
  most_recent = true
  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
  name_regex = ".+-amazon-ecs-optimized$"
  most_recent = true
}

resource "aws_iam_instance_profile" "test-instance-profile" {
  name = "test-instance-profile"
  role = "${aws_iam_role.TestEcsRole.name}"
}

resource "aws_iam_role" "TestEcsRole" {
  name = "TestEcsRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["ecs.amazonaws.com", "ec2.amazonaws.com"]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_launch_configuration" "test-lc" {
  name = "test-lc"
  image_id = "${data.aws_ami.ecs-ami.id}"
  instance_type = "t2.micro"

  spot_price    = "0.008"

  lifecycle {
    create_before_destroy = true
  }

  security_groups = ["${aws_security_group.test-ec2-sg.id}"]
  user_data =  "${file("user_data.sh")}"
  iam_instance_profile = "${aws_iam_instance_profile.test-instance-profile.name}"
}

resource "aws_autoscaling_group" "test-ag" {
  name     = "test-ag"
  desired_capacity = 1
  min_size = 1
  max_size = 2
  
  availability_zones = ["ap-northeast-2a", "ap-northeast-2c"]
  launch_configuration = "${aws_launch_configuration.test-lc.id}"
}


resource "aws_ecs_cluster" "test-ecs" {
  name = "test-ecs-cluster"
}
