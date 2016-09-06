class Chef
  class Recipe

    # Load or create a RSA key pair
    def get_or_create_rsa(keypath, comment="timemachine RSA key")
      if File.exist?(keypath)
        privkey = File.read("#{keypath}").strip()
        pubkey = File.read("#{keypath}.pub").strip()
      else
        chef_gem 'sshkey'
        require 'sshkey'
        sshkey = SSHKey.generate(type: 'RSA', comment: comment)
        privkey = sshkey.private_key
        pubkey = sshkey.ssh_public_key
      end
      return privkey, pubkey
    end

  end
end
