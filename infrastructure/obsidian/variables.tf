variable "ec2_ami_owners" {
  type        = list(string)
  default     = []
  description = "A list of owners of the EC2 AMI instance."
}