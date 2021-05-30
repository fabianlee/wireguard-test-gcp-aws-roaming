
output "aws-ubuntu-pub-wg_public_ip" {
  value = aws_instance.wgserver.public_ip
}
output "aws-ubuntu-pub-wg_private_ip" {
  value = aws_instance.wgserver.private_ip
}

#output "aws-ubuntu-priv-web-public_ip" {
#  value = aws_instance.web.public_ip
#}
output "aws-ubuntu-priv-web-private_ip" {
  value = aws_instance.web.private_ip
}
