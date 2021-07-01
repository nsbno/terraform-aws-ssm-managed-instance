# ecs-anywhere
This example describes how to use the module to register an instance with both SSM and ECS, and run an example container on the instance using ECS Anywhere.

## Usage
1. Authenticate your shell with AWS.
2. Run `terraform init && terraform apply` _(this will create an SSM activation, a role for the managed instance and the necessary ECS resources.)_
3. SSH into the instance you want to register with SSM, and run the following shell commands (replacing the `<placeholder>` placeholders with your values):

   ℹ _The following commands will install the SSM agent, register the instance with SSM, install the ECS agent and register the instance with ECS_
```sh
$ curl --proto https -o /tmp/ecs-anywhere-install.sh "https://raw.githubusercontent.com/aws/amazon-ecs-init/v1.53.0-1/scripts/ecs-anywhere-install.sh"
$ echo '5ea39e5af247b93e77373c35530d65887857b8d14539465fa7132d33d8077c8c  /tmp/ecs-anywhere-install.sh' \
  | sha256sum -c - \
  && sudo bash /tmp/ecs-anywhere-install.sh \
    --region "<aws-region>" \
    --cluster "<ecs-cluster>" \
    --activation-id "<activation-id>" \
    --activation-code "<activation-code>"
```


To clean up:
1. First manually deregister the SSM and ECS instance. In the AWS Console:
    1. Go to **Elastic Container Service** > **example-cluster** > **ECS Instances**
    2. Click on the container instance > **Deregister** > ✅ **Deregister from AWS Systems Manager** > **Deregister**
3. Run `terraform destroy` to remove the remaining resources created in this example.
