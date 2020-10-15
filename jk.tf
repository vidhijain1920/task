
provider "aws"{
region = "ap-south-1"
profile = "kcjprofile"

}


resource "aws_security_group" "allow_tls11" {
  name        = "sgtt"
 
  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_tls1"
  }
}

resource "aws_instance" "vj" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name ="webos"
security_groups =["sgtt"]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/ASUS/Downloads/webos.pem")
    host     = aws_instance.vj.public_ip
  }

  provisioner "remote-exec" {
    inline = [
       "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "HelloWorld"
  }
}


resource "aws_ebs_volume" "ebsv" {
  availability_zone =  aws_instance.vj.availability_zone
  size              = 1

  tags = {
    Name = "disk"
  }
}



resource "aws_volume_attachment" "ebs1" {
  device_name = "/dev/sdh"

  volume_id   = "${aws_ebs_volume.ebsv.id}"
  instance_id = "${aws_instance.vj.id}"
  force_detach = true
}



resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.ebs1,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/ASUS/Downloads/webos.pem")
    host     = aws_instance.vj.public_ip
  }

provisioner "remote-exec" {

    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/vaibhavjain2099/task.git  /var/www/html/" ,
 "echo \"${aws_cloudfront_distribution.s3_distribution.domain_name}\" >> /var/www/html/mydesti.txt",
      "EOF",
     "sudo systemctl restart httpd"
    ]
  }
}




resource "aws_s3_bucket" "mavj1" {
  bucket = "maamb"
acl = "public-read"

  tags = {
    Name = "jaiho"
  }
}

resource "null_resource" "download-s3"{
provisioner "local-exec" {
command =  "git clone https://github.com/vaibhavjain2099/task.git task"
}
provisioner "local-exec" {
when = destroy
command =  "echo Y | rmdir /s task"
}


}


resource "aws_s3_bucket_object" "VJIMAGE" {
depends_on = [ aws_s3_bucket.mavj1,
                null_resource.download-s3]
  bucket = "maamb"
  key    = "IMG-20191016-WA0023.jpg"
  source = "task/IMG-20191016-WA0023.jpg"
  acl = "public-read-write"
}


resource "aws_cloudfront_distribution" "s3_distribution" {

  origin {
    domain_name = "mavj1.s3.amazonaws.com"
    origin_id   = "s3-mavj1"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  


  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-mavj1"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "s3-mavj1"

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }


  tags = {
    Environment = "production"
  }
  restrictions {
    geo_restriction {
      restriction_type = "blacklist"
      locations        = ["US", "CA", "GB"]
    }
  }


  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource  "null_resource"  "myresource1"{
depends_on=[
            null_resource.nullremote3,
            aws_cloudfront_distribution.s3_distribution

]
provisioner "local-exec" {
    command = "start chrome ${aws_instance.vj.public_ip}"
  }
}
