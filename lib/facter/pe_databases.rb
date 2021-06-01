Facter.add(:pe_databases, type: :aggregate) do
  confine kernel: 'Linux'

  chunk(:have_systemd) do
    if Puppet::FileSystem.exist?('/proc/1/comm') && Puppet::FileSystem.read('/proc/1/comm').include?('systemd')
      { have_systemd: true }
    else
      { have_systemd: false }
    end
  end
end
