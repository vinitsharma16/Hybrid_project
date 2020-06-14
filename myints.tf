provider "aws" {
  region = "ap-south-1"
  profile = "myprofile"
}


resource "aws_security_group" "webos-secgu" {
  name        = "webos-secgu"
  description = "allow ssh and http traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_ebs_volume" "web" {
	availability_zone  = "ap-south-1a"
	type	   = "gp2"
	size		   = 1
	tags		   = {
		Name = "webebs"
	}
}

resource "aws_instance" "vinitos" {
	ami		   = "ami-005956c5f0f757d37"
	availability_zone  = "ap-south-1a"
	instance_type	   = "t2.micro"
	security_groups	   = ["${aws_security_group.webos-secgu.name}"]
	user_data	   = <<-EOF
			       #! /bin/bash
			       sudo su - root
			       yum install httpd -y
			       yum install php -y
			       yum install git -y
			       yum update -y
			       service httpd start
			       chkconfig --add httpd


	EOF
	tags		   = {
		Name = "webserver-php"
	}
}
resource "aws_volume_attachment" "ebs_att" {
	device_name  = "/dev/sdc"
	volume_id    = "${aws_ebs_volume.web.id}"
	instance_id  = "${aws_instance.vinitos.id}"
	force_detach = true
}

resource "null_resource" "format_git" {

	connection {
		type  = "ssh"
		user  = "ec2-user"
		private_key  = file("C:/Users/vinit/Downloads/mykey.pem")
		host  = aws_instance.vinitos.public_ip
	}
	provisioner "remote-exec" {
		inline = [ 
			     "sudo mkfs -t ext4 /dev/xvdc",
			     "sudo mount /dev/xvdc /var/www/html",
			     "sudo rm -rf /var/www/html/*",
			     "sudo git clone https://github.com/vinitsharma16/Hybrid_project.git /var/www/html/",
		]
		
	}
	depends_on  = ["aws_volume_attachment.ebs_att"]
}

resource "aws_s3_bucket" "vinitstg" {
  bucket = "vinitstg"
  acl    = "public-read"
  force_destroy  = true
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST"]
    allowed_origins = ["https://Vinitstg"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "null_resource" "remove_and_upload_to_s3" {
  provisioner "local-exec" {
    command = "C:/Users/vinit/Desktop/tera/s3update.bat"
  }
  depends_on  = ["aws_s3_bucket.vinitstg"]
}



resource "aws_cloudfront_distribution" "distribution" {
    origin {
        domain_name = "${aws_s3_bucket.vinitstg.bucket_regional_domain_name}"
        origin_id = "S3-${aws_s3_bucket.vinitstg.bucket}"
 
        custom_origin_config {
            http_port = 80
            https_port = 443
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
        }
    }

    default_root_object = "tricolor.html"
    enabled = true

    
    custom_error_response {
        error_caching_min_ttl = 3000
        error_code = 404
        response_code = 200
        response_page_path = "/tricolor.html"
    }

    default_cache_behavior {
        allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = "S3-${aws_s3_bucket.vinitstg.bucket}"

        #Not Forward all query strings, cookies and headers
        forwarded_values {
            query_string = false
	    cookies {
		forward = "none"
	    }
            
        }

        viewer_protocol_policy = "redirect-to-https"
        min_ttl = 0
        default_ttl = 3600
        max_ttl = 86400
    }

   
    price_class = "PriceClass_All"


    restrictions {
        geo_restriction {
        
            restriction_type = "none"
        }
    }

    
    viewer_certificate {
        cloudfront_default_certificate = true
    }
}
output "cloudfront_ip_addr" {
  value = aws_cloudfront_distribution.distribution.domain_name
}
