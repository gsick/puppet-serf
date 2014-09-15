class serf(
  $version  = '0.6.3',
  $conf_dir = '/etc/serf',
  $conf     = {},
  $tmp      = '/tmp',
) {

  validate_string($version)
  validate_absolute_path($conf_dir)
  validate_absolute_path($tmp)

  ensure_packages(['wget', 'unzip'])

  file { 'serf conf dir':
    ensure => directory,
    path   => $conf_dir,
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
    command => "cp ${tmp}/serf /usr/local/bin/",
    creates => '/usr/local/bin/serf',
    notify  => Service['serf'],
  }

  file { 'serf svc link':
    ensure  => 'link',
    path    => '/usr/bin/serf',
    target  => '/usr/local/bin/serf',
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
