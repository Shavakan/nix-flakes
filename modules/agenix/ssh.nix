let
  # Your SSH key - Using identity from ~/.ssh/ directory
  # This tries multiple possible keys to increase chances of success
  sshKeysFromIdentity = [
    # Public keys that should match your private key
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHP1NSXj1F65vAVy4o/oYMh9w77pu8+KnXc16JANnCsB changwon.lee@devsisters.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGOh9iL7pSgqgbuDvGM9qwCWSBLPX0A6WaMMmR8R2WHB chiyah92@gmail.com"
    # Add more keys as needed
  ];
  
  # Use all keys for maximum compatibility
  allKeys = sshKeysFromIdentity;
in
{
  # rclone configuration file - accessible by any of the keys
  "modules/agenix/rclone.conf.age".publicKeys = allKeys;
}
