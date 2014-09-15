class serf(
  $version   = '0.6.3',
  $node_name = $::hostname,
  $conf_dir  = '/etc/serf',
  $conf      = {},
  $user      = 'root',
  $group     = 'root',
  $tmp       = '/tmp',
) {

  validate_string($version)
  validate_string($node_name)
  validate_hash($conf)
  validate_absolute_path($conf_dir)
  validate_absolute_path($tmp)

  ensure_packages(['wget', 'unzip'])

  if(empty($conf['bind'])) {
    $bind = "${ipaddress_eth0}:${conf['port']}"
  }

  $conf_tmp = merge($conf, {bind => $bind, node_name => $node_name})

  group { 'serf group':
    ensure => present,
    name   => $group,
  }

  user { 'serf user':
    ensure     => present,
    name       => $user,
    groups     => $group,
    managehome => true,
    shell      => '/bin/bash',
    require    => Group['serf group'],
  }

  file { 'serf conf dir':
    ensure => directory,
    path   => $conf_dir,
  }

  file { 'serf local dir':
    ensure  => directory,
    path    => '/usr/local/serf',
    owner   => $user,
    group   => $group,
    require => User['serf user'],
  }

  file { 'serf local bin dir':
    ensure  => directory,
    path    => '/usr/local/serf/bin',
    require => File['serf local dir'],
    owner   => $user,
    group   => $group,
    require => User['serf user'],
  }

  exec { 'download serf':
    cwd     => $tmp,
    path    => '/sbin:/bin:/usr/bin',
    command => "wget https://dl.bintray.com/mitchellh/serf/${version}_linux_amd64.zip",
    creates => "${tmp}/${version}_linux_amd64.zip",
    notify  => Exec['unzip serf'],
    require => Package['wget'],
  }

  exec { 'unzip serf':
    cwd     => $tmp,
    path    => '/sbin:/bin:/usr/bin',
    command => "unzip ${version}_linux_amd64.zip",
    creates => "${tmp}/serf",
    notify  => Exec['install serf'],
  }

  exec { 'install serf':
    cwd     => $tmp,
    path    => '/sbin:/bin:/usr/bin',
    command => "cp ${tmp}/serf /usr/local/serf/bin/",
    creates => '/usr/local/serf/bin/serf',
    notify  => [Service['serf'], File['serf local bin dir']],
  }

  file { 'serf svc link':
    ensure  => 'link',
    path    => '/usr/bin/serf',
    target  => '/usr/local/serf/bin/serf',
    require => Exec['install serf'],
    notify  => Service['serf'],
  }

  file { 'serf conf':
    ensure  => 'file',
    path    => '/etc/serf/serf.json',
    content => template("${module_name}/serf.json.erb"),
    mode    => '0644',
    require => File['serf conf dir'],
    notify  => Service['serf'],
  }

  file { 'serf init script':
    ensure  => 'file',
    path    => '/etc/init.d/serf',
    content => template("${module_name}/serf.erb"),
    owner   => 'root',
    group   => 'root',
    mode    => '755',
    notify  => Service['serf'],
  }

  service { 'serf':
    ensure     => running,
    name       => 'serf',
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    require    => [File['serf init script', 'serf conf', 'serf svc link'], Exec['install serf']],
  }
}
