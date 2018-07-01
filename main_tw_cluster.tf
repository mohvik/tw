# ThoughtWorks: DevOps_Test Project for CompanyNews deployment on AWS

# ------------------------------------------------------------
# ThoughtWorks: AWS login credentials, Region : Mumbai
# ------------------------------------------------------------

provider "aws" {
  region = "ap-south-1"
}

data "aws_availability_zones" "all" {}

# ------------------------------------------------------------
# ThoughtWorks: Auto Scaling Group creation
# ------------------------------------------------------------
 
resource "aws_autoscaling_group" "thoughtworks" {
  launch_configuration = "${aws_launch_configuration.thoughtworks.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  
  min_size = 2
  max_size = 5

  load_balancers = ["${aws_elb.thoughtworks.name}"]
  health_check_type = "ELB"

  tag {
    key = "Name"
    value = "terraform-asg-thoughtworks"
    propagate_at_launch = true
  }
}

# ------------------------------------------------------------
# ThoughtWorks: Creating EC2 instances 
# ------------------------------------------------------------

resource "aws_launch_configuration" "thoughtworks" {
  image_id = "ami-0646928ef4b88ccfc"
  instance_type = "t2.micro"
  key_name = "twkey"
  security_groups = ["${aws_security_group.instance.id}"]

  user_data = <<-EOF
              #!/bin/bash
              wget https://github.com/mohvik/tw/raw/master/companyNews.war
              sudo cp companyNews.war /opt/apache-tomcat-7.0.88/webapps/
              sudo /opt/apache-tomcat-7.0.88/bin/catalina.sh start
              EOF
  
  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------
# ThoughtWorks: Creating Security Group for traffic control
# ------------------------------------------------------------

resource "aws_security_group" "instance" {
  name = "terraform-thoughtworks-instance"

  # Allow all outbound traffic allowed
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Inbound HTTP from anywhere allowed
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound SSH from anywhere allowed
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "allow_all"
  }

  lifecycle {
    create_before_destroy = true
  }
  
}

# ------------------------------------------------------------
# ThoughtWorks: Creating ELB to route traffic to EC2 instances
# ------------------------------------------------------------

resource "aws_elb" "thoughtworks" {
  name = "terraform-asg-thoughtworks"
  security_groups = ["${aws_security_group.elb.id}"]
  availability_zones = ["${data.aws_availability_zones.all.names}"]

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:8080/"
  }

  # Listener for incoming HTTP requests.
  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = 8080
    instance_protocol = "http"
  }
  
}

# ------------------------------------------------------------
# ThoughtWorks: Creating security group for ELB
# ------------------------------------------------------------

resource "aws_security_group" "elb" {
  name = "terraform-thoughtworks-elb"

  # Allow all outbound
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound HTTP from anywhere
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound SSH from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }  
  
}

output "elb_dns_name" {
  value = "${aws_elb.thoughtworks.dns_name}"
}
