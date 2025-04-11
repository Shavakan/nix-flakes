let
  # Your SSH key
  myKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHP1NSXj1F65vAVy4o/oYMh9w77pu8+KnXc16JANnCsB changwon.lee@devsisters.com";
  
  # Add more keys for other machines if needed
  allKeys = [ myKey ];
in
{
  # rclone configuration file
  "secrets/rclone.conf.age".publicKeys = allKeys;
}
