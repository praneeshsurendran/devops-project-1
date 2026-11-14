module "networking"{
    source = "./modules/vpc"
    vpc_cidr = "10.0.0.0/16"
    env_name = "dev"
}

module "compute"{
    source = "./modules/ec2"
    vpc_id     = module.networking.vpc_id
    subnet_id = module.networking.public_subnet_id
    env_name = "dev"
    public_key = var.public_key
}