# Configure the AWS provider
provider "aws" {
  region = "ap-south-1"

}

terraform {
  backend "s3" {
    bucket = "mytest-remote-backends"
    key    = "mystaefile.tfstate"           # it will save this name in s3 we can give preifix also
    region = "ap-south-1"
    dynamodb_table = "terraform-state-lock-dynamo"   # dynamodb table name
  }
}

# resource "aws_placement_group" "test" {
#   name     = "test"
#   strategy = "cluster"
# }

data "aws_key_pair" "example" {
  key_name           = "newkey"
  include_public_key = true


}

output "fingerprint" {
  value = data.aws_key_pair.example.fingerprint
}

output "name" {
  value = data.aws_key_pair.example.key_name
}

output "id" {
  value = data.aws_key_pair.example.id
}




resource "aws_autoscaling_group" "bar" {
  name                      = "myascggroup"
  max_size                  = 2
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "ELB"
  # desired_capacity          = 2
  force_delete = true
  # placement_group           = aws_placement_group.test.id
  #launch_configuration      = aws_launch_configuration.foobar.id
  availability_zones = ["ap-south-1a"]

  launch_template {
    id      = aws_launch_template.foobar.id
    version = "$Latest"
  }

  tag {
    key                 = "foo"
    value               = "bar"
    propagate_at_launch = true
  }

  timeouts {
    delete = "15m"
  }

  tag {
    key                 = "lorem"
    value               = "ipsum"
    propagate_at_launch = false
  }
}


# resource "aws_network_interface" "test" {
#   subnet_id       = "subnet-0f215003fb4fb765b"
#   private_ips     = ["172.31.0.0"]
#   security_groups = ["sg-014748c93b7aa5073"]
#   description     = "Test network interface"
# }


resource "aws_launch_template" "foobar" {
  name = "foobar"

  # block_device_mappings {
  #   device_name = "/dev/sdf"

  #   ebs {
  #     volume_size = 20
  #   }
  # }
  image_id = "ami-0f8ca728008ff5af4"
  # ebs_optimized = true
  instance_type = "t2.micro"

  vpc_security_group_ids = ["sg-014748c93b7aa5073"]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "test"
    }
  }
  key_name = data.aws_key_pair.example.key_name



  user_data = base64encode(
    <<-EOF
          #!/bin/bash
          sudo apt update -y
          sudo apt-get install -y nfs-common
          sudo mkdir -p /mnt/efs
          sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 ${aws_efs_file_system.efs.dns_name}:/ /mnt/efs
          sudo apt install apache2 -y
          sudo systemctl start apache2
          sudo echo "your very first web server" > /var/www/html/index.html
          sudo echo "your very first web server" > /mnt/efs/index.html
  EOF
  )

  depends_on = [
    aws_efs_mount_target.mount
  ]
}

#################  ELB 

# Create a new load balancer
resource "aws_elb" "bar" {
  name               = "foobar-terraform-elb"
  availability_zones = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]


  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  # listener {
  #   instance_port     = 2049
  #   instance_protocol = "tcp"
  #   lb_port           = 2049
  #   lb_protocol       = "tcp"
  # }




  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }


  # instances                   = [aws_autoscaling_group.bar.name]
  # cross_zone_load_balancing   = true
  # idle_timeout                = 400
  # connection_draining         = true
  # connection_draining_timeout = 400



}
resource "aws_autoscaling_attachment" "asg_attachment_bar" {
  autoscaling_group_name = aws_autoscaling_group.bar.name
  elb                    = aws_elb.bar.id
}


# Creating EFS file system
resource "aws_efs_file_system" "efs" {
  creation_token = "my-efs"
  tags = {
    Name = "MyProduct"
  }
}
# Creating Mount target of EFS
resource "aws_efs_mount_target" "mount" {
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = "subnet-0f215003fb4fb765b"
  security_groups = ["sg-014748c93b7aa5073"]
}
# Creating Mount Point for EFS
# resource "null_resource" "configure_nfs" {
# depends_on = [aws_efs_mount_target.mount]
# connection {
# type     = "ssh"
# user     = "ec2-user"
# private_key = tls_private_key.my_key.private_key_pem
# host     = aws_instance.web.public_ip
#  }
# }
