output "jenkins_public_ip" {
value = module.ec2.jenkins_public_ip
}

output "myapp_secrets_role_arn" {
  value = module.secretmanager.myapp_secrets_role_arn
}