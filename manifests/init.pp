class jenkins {
  include jenkins::upstream

  jenkins-plugin { 'git':
      name => 'git',
      ensure => present,
  }

  jenkins-plugin { 'chucknorris':
      name => 'chucknorris',
      ensure => present,
  }

  jenkins-plugin { 'disk-usage':
      name => 'disk-usage',
      ensure => present,
  }

  jenkins-plugin { 'github':
      name => 'github',
      ensure => present,
  }

  jenkins-plugin { 'maven-plugin':
      name => 'maven-plugin',
      ensure => absent,
  }

  jenkins-plugin { 'ssh-slaves':
      name => 'ssh-slaves',
      ensure => absent,
  }

}

class jenkins::upstream {
  include jenkins::repo
  include jenkins::package
  include jenkins::config

  Class["jenkins::repo"] -> Class["jenkins::package"] -> Class["jenkins::config"] 
}

class jenkins::config {
  group { "jenkins":
          ensure => present
  }
  file { '/var/lib/jenkins/users':
    ensure => directory,
    group => jenkins,
    owner => jenkins
  }
  file { '/var/lib/jenkins/users/djm':
    ensure => directory,
    group => jenkins,
    owner => jenkins 
  }
  file { '/var/lib/jenkins/users/djm/config.xml':
    source => 'puppet:///modules/jenkins/jenkins_user.xml',
    group => jenkins,
    owner => jenkins,
    ensure => present
  }
  file { '/var/lib/jenkins/jobs':
    ensure => directory,
    group => jenkins,
    owner => jenkins 
  }
  file { '/var/lib/jenkins/jobs/facter':
    ensure => directory,
    group => jenkins,
    owner => jenkins 
  }
  file {'/var/lib/jenkins/jobs/facter/config.xml':
    source => 'puppet:///modules/jenkins/facter_job.xml',
    group => jenkins,
    owner => jenkins,
    ensure => present
  } 
}

class jenkins::package {
  package {
    "jenkins" :
      ensure => installed;
  }

  service {
    'jenkins':
      ensure => running,
      enable => true,
      hasstatus => true,
      hasrestart => true,
      require => Package['jenkins'],
  }
}

class jenkins::repo {
  file {
      "/etc/apt/sources.list.d" :
          ensure => directory;

      "/etc/apt/sources.list.d/jenkins.list" :
          ensure => present,
          notify => [
                      Exec["install-key"],
                      Exec["refresh-apt"],
                    ],
          source => "puppet:///modules/jenkins/apt.list",
  }

  file {
      "/root/jenkins-ci.org.key" :
          source => "puppet:///modules/jenkins/jenkins-ci.org.key",
          ensure => present;
  }

  exec {
      "refresh-apt" :
          refreshonly => true,
          require => [
                      File["/etc/apt/sources.list.d/jenkins.list"],
                      Exec["install-key"],
                      ],
          path    => ["/usr/bin", "/usr/sbin"],
          command => "apt-get update";

      "install-key" :
          notify => Exec["refresh-apt"],
          require => [
                      File["/etc/apt/sources.list.d/jenkins.list"],
                      File["/root/jenkins-ci.org.key"],
                      ],
          # Don't install the key unless it's not already installed
          unless  => "/usr/bin/apt-key list | grep 'D50582E6'",
          command => "/usr/bin/apt-key add /root/jenkins-ci.org.key";
  }
}

define jenkins-plugin($name, $version=0, $ensure=present) {
  $plugin     = "${name}.hpi"
  $plugin_dir = "/var/lib/jenkins/plugins"

  if ($version != 0) {
    $base_url = "http://updates.jenkins-ci.org/download/plugins/${name}/${version}/"
  }
  else {
    $base_url   = "http://updates.jenkins-ci.org/latest/"
  }

  if (!defined(File["${plugin_dir}"])) {
    file {
      "${plugin_dir}" :
        owner  => "jenkins",
        ensure => directory;
    }
  }

  if (!defined(User["jenkins"])) {
    user {
      "jenkins" :
        ensure => present;
    }
  }

  exec {
    "download-${name}" :
      command  => "wget --no-check-certificate ${base_url}${plugin}",
      cwd      => "${plugin_dir}",
      require  => File["${plugin_dir}"],
      path     => ["/usr/bin", "/usr/sbin",],
      user     => "jenkins",
      creates   => "${plugin_dir}/${plugin}",
      onlyif => $ensure ? {
        present => 'test -n "1"',
        absent => 'test -n ""',
      },
  }

  file { 
    "${plugin_dir}/${plugin}":
      owner => 'jenkins',
      ensure => $ensure,
      require => Exec["download-${name}"],
      mode => '640',
      notify => Service['jenkins'],
  }
}

# vim: ts=2 et sw=2 autoindent
