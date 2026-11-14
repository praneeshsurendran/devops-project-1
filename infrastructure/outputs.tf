output "server_public_ip" {
  value = module.compute.public_ip
}

output "server_public_dns" {
  value = module.compute.public_dns
}