// providers are the plugins you use
// to build infrastructure in Terraform by
// communicating with an API - in this case aws

provider "aws"  {
  region = "eu-central-1"
  access_key = var.access_key
  secret_key  = var.secret_key 
}


// A resource is a Terraform component used to create and
// manage infrastrucure - they can be objects or services
// NOTE: the resource name is provider_resourcetype so here aws is the provider
// and lightsail_instance is the resource type - providers have repositories of resources

resource "aws_lightsail_instance"  "test_terraform" {
  name = "test_terraform"
  availability_zone = "eu-central-1a"
  blueprint_id = "ubuntu_24_04"
  bundle_id = "nano_2_0"
  tags = { "Steve Terraform" = "true"
  }
  user_data = <<-EOF
    #!/bin/bash
    mkdir -p /home/ubuntu/.ssh
    echo "${var.ssh_pub_key}" > /home/ubuntu/.ssh/authorized_keys
    chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys
    chmod 600 /home/ubuntu/.ssh/authorized_keys
    EOF

// the ssh connection lets Terraform run commands on the newly created instance
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("/Users/stevenalbury/.ssh/id_ed25519")
    host        = self.public_ip_address
  }

// the file provisioner copies things from source to destination - destination must exist
// and must have permissions - easiest is to copy to /tmp then move
  provisioner "file" {
        source = "./flask-redis/compose.yaml"
        destination = "/tmp/compose.yaml"
  }

  provisioner "file" {
        source      = "flask-redis"
        destination = "/tmp/flask-redis"
  }

// this runs commands - the created user will need to be able to run sudo so 
// whatever OS is used to build the instance it must have sudo available or too many things
// can't be done

  provisioner "remote-exec" {
    inline = [
       "sudo apt-get update",
       "sudo apt-get install -y docker.io",
       "sudo curl -L https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose",
       "sudo chmod +x /usr/local/bin/docker-compose",
       "sudo mv /tmp/flask-redis /home/ubuntu/",
       "sudo mv /tmp/compose.yaml /home/ubuntu/flask-redisa",
       "sudo chown ubuntu:ubuntu /home/ubuntu/flask-redis/compose.yaml",
       "export COMPOSE_DOCKER_CLI_BUILD=1",
       "export DOCKER_BUILDKIT=1",
       "sudo chmod 755 /home/ubuntu/flask-redis",
       "sudo -s docker-compose -f /home/ubuntu/flask-redis/compose.yaml up -d"
       ]

    // I moved the connection which I didn't think needed moving as Terraform is declarative
    // but it needed to happen earlier for doing the file copy.
    //  connection {
    //type        = "ssh"
    //user        = "ubuntu"
    //private_key = file("/Users/stevenalbury/.ssh/id_ed25519")
    //host        = self.public_ip_address
    //} 
  }
}
