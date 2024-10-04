# Provider configuration
provider "aws" {
  region = "ap-southeast-2" # Modify this region as per your choice
}

# Create a VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create a public subnet in the VPC
resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-southeast-2a"
}

# Create an Internet Gateway for the VPC
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id
}

# Create a route table for the public subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id
}

# Create a default route through the Internet Gateway
resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main_igw.id
}

# Associate the route table with the public subnet
resource "aws_route_table_association" "subnet_association" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Create a security group for the EC2 instance
resource "aws_security_group" "my_sg" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow SSH from anywhere, adjust as needed
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow HTTP from anywhere
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "my_security_group"
  }
}

# Create an EC2 instance
resource "aws_instance" "my_ec2" {
  ami                    = "ami-0474411b350de35fb"  # Example Amazon Linux 2 AMI, update as needed
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.main_subnet.id
  vpc_security_group_ids = [aws_security_group.my_sg.id] # Use security group ID

  tags = {
    Name = "MyAppServer"
  }
}

# Create API Gateway
resource "aws_api_gateway_rest_api" "my_api" {
  name        = "MyAPIGateway"
  description = "API Gateway for my app"
}

# Define a resource for the API Gateway
resource "aws_api_gateway_resource" "my_resource" {
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  parent_id   = aws_api_gateway_rest_api.my_api.root_resource_id
  path_part   = "myresource"
}

# Define the method for the API Gateway
resource "aws_api_gateway_method" "get_method" {
  rest_api_id   = aws_api_gateway_rest_api.my_api.id
  resource_id   = aws_api_gateway_resource.my_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

# Define the integration for the API Gateway method (for example, Lambda or HTTP backend)
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id            = aws_api_gateway_rest_api.my_api.id
  resource_id            = aws_api_gateway_resource.my_resource.id
  http_method            = aws_api_gateway_method.get_method.http_method
  integration_http_method = "POST"  # Use POST when integrating with a backend
  type                   = "MOCK"  # Use "MOCK" if no backend, otherwise specify "AWS_PROXY" for Lambda or "HTTP" for HTTP backends
  uri                    = "https://jsonplaceholder.typicode.com/todos/1"  # Example external HTTP integration (replace with actual backend)
}

# Deploy the API Gateway
resource "aws_api_gateway_deployment" "deployment" {
  depends_on  = [aws_api_gateway_integration.lambda_integration]
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  stage_name  = "prod"
}

# Output EC2 public IP
output "instance_public_ip" {
  value = aws_instance.my_ec2.public_ip
}

# Output the API Gateway URL
output "api_gateway_url" {
  value = "${aws_api_gateway_deployment.deployment.invoke_url}/prod/myresource"
}
