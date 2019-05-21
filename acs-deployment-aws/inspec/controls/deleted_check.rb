# Alfresco Enterprise ACS Deployment AWS
# Copyright (C) 2005 - 2018 Alfresco Software Limited
# License rights for this program may be obtained from Alfresco Software, Ltd.
# pursuant to a written agreement and any use of this program without such an
# agreement is prohibited.

AcsBaseDnsName = attribute('AcsBaseDnsName', description: 'K8s Release')
Bastion = attribute('BastionInstanceName', default: '', description: 'K8s BastionInstanceName')
S3BucketName = attribute('S3BucketName', default: '', description: 'K8s S3BucketName')

# check if alfresco DNS is not available anymore
describe command("curl -v https://#{AcsBaseDnsName} --connect-timeout 5") do
  its('exit_status') { should eq 6 }
end

# Check if bastion is deleted

describe "Check if bastion instance still exists" do

  let(:checkinstance) { command("aws ec2 describe-instances --filters 'Name=tag:Name,Values=#{Bastion}' --query 'Reservations[].Instances[].State.Name' --output text") }

    it "should return exist status 0" do
      expect(checkinstance.exit_status).to eq 0
    end

    it "its stdout should either be nothing or terminated" do
      expect(checkinstance.stdout).to eq("terminated\n").or eq("")
    end

    it "its stderr return nothing" do
      expect(checkinstance.stderr).to eq("")
    end

end

# Check if Bucket is deleted
describe command("aws s3 ls s3://#{S3BucketName}") do
  its('exit_status') { should_not eq 0 }
  its('stdout') { should eq "" }
  its('stderr') { should match /.*NoSuchBucket.*/ }
end

# Check if EKS Cluster is deleted
describe command('kubectl get svc -n kube-system') do
  its('exit_status') { should eq 1 }
  its('stdout') { should eq "" }
  its('stderr') { should match /.*no such host.*/ }
end
