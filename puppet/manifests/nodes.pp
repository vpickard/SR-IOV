node basenode {

  exec { "apt_get_update":
    command => "/usr/bin/apt-get -y update"
    # command => "/usr/bin/apt-get -y install dh-autoreconf"
  }
  


  # Ensure the above command runs before we attempt
  # to install any package in other manifests
  Exec["apt_get_update"] -> Package<| |>

  $base_packages = [
                     "git",
                     "autoconf",
                     "automake1.10",
                     "build-essential",
                     "debhelper",
                     "dh-autoreconf",
                     "fakeroot",
                     "libffi-dev",
                     "libssl-dev",
                     "libtool",
                     "vlan",
                     "pkg-config",
                     "python-all",
                     "python-qt4",
                     "python-zopeinterface",
                     "python-twisted-conch"
                   ]

  package { $base_packages:
    ensure => installed,
  }

  exec { "download_ovs":
    #command => "/usr/bin/wget https://github.com/openvswitch/ovs/archive/v2.3.tar.gz -O /root/ovs.tar.gz",
    #command => "/usr/bin/wget http://openvswitch.org/releases/openvswitch-2.3.3.tar.gz -O /root/ovs.tar.gz",
    #command => "/usr/bin/wget http://openvswitch.org/releases/openvswitch-2.5.0.tar.gz -O /root/ovs.tar.gz",
    #command => "/usr/bin/wget http://openvswitch.org/releases/openvswitch-2.4.0.tar.gz -O /root/ovs.tar.gz",
    command => "/usr/bin/wget http://openvswitch.org/releases/openvswitch-2.6.1.tar.gz -O /root/ovs.tar.gz",
    cwd     => "/root",
    creates => "/root/ovs.tar.gz",
  }

  file { "/root/ovs":
    ensure => directory,
  }

  exec { "extract_ovs":
    command => "/bin/tar xvfz ovs.tar.gz -C /root/ovs --strip-components=1",
    cwd     => "/root",
    require => [
                  Exec["download_ovs"],
               ],
    creates => "/root/ovs/README",
  }

  exec { "build_ovs":
    command     => "/usr/bin/fakeroot debian/rules binary",
    environment => "DEB_BUILD_OPTIONS='parallel=8 nocheck'",
    cwd         => "/root/ovs",
    logoutput   => true,
    loglevel    => verbose,
    timeout     => 0,
    creates     => "/root/openvswitch-common_2.6.1-1_amd64.deb",
    require     => [
                     Package["build-essential"],
                     Package["fakeroot"],
                     Package[$base_packages],
                     Exec["extract_ovs"],
                   ],
  }

  package { "ovs_common":
    name     =>  "openvswitch-common",
    ensure   =>  installed,
    provider =>  dpkg,
    source   =>  "/root/openvswitch-common_2.6.1-1_amd64.deb",
    require  => [ Exec["build_ovs"] ],
  }

  package { "ovs_switch":
    name     =>  "openvswitch-switch",
    ensure   =>  installed,
    provider =>  dpkg,
    source   =>  "/root/openvswitch-switch_2.6.1-1_amd64.deb",
    require  => [ Package["ovs_common"] ],
  }

}

node devStack inherits basenode {

  #file { '/opt/devstack':
  #   ensure => 'directory',
  #   owner  => 'root'
  #}

  exec { "download_devstack":
    cwd     => "/opt/",
    creates => "/opt/devstack",
    #command => "/usr/bin/git clone https://git.openstack.org/openstack-dev/devstack -b stable/mitaka "
    #command => "/usr/bin/git clone https://git.openstack.org/openstack-dev/devstack -b stable/newton "
    command => "/usr/bin/git clone https://git.openstack.org/openstack-dev/devstack -b master "
  }
}



node hwvtepnode inherits basenode {

  package { "ovs_python":
    name     =>  "python-openvswitch",
    ensure   =>  installed,
    provider =>  dpkg,
    source   =>  "/root/python-openvswitch_2.6.1-1_all.deb",
    require  => [ Package["ovs_switch"] ],
  }

  package { "ovs_vtep":
    name     =>  "openvswitch-vtep",
    ensure   =>  installed,
    provider =>  dpkg,
    source   =>  "/root/openvswitch-vtep_2.6.1-1_amd64.deb",
    require  => [ Package["ovs_python"] ],
  }

  package { "mininet":
    ensure => installed,
    require => [
                  Package["ovs_switch"],
               ]
  }

}



import 'nodes/*.pp'
