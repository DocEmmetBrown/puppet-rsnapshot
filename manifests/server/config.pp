define rsnapshot::server::config (
  $config_path = undef,
  $log_path = undef,
  $backup_path = undef,
  $backup_user = undef,
  $directories = {},
  $lock_path = undef,
  $includes = {},
  $excludes = {},
  $include_files = {},
  $exclude_files = {},
  $config_path = undef,
  $log_path = undef,
  $lock_path = undef,
  $remote_user = undef,
  $no_create_root = undef,
  $verbose = undef,
  $log_level = undef,
  $link_dest = undef,
  $sync_first = undef,
  $use_lazy_deletes = undef,
  $rsync_numtries = undef,
  $stop_on_stale_lockfile = undef,
  $user = undef,
  $server = undef,
  $backup_hourly_cron = undef,
  $backup_time_minute = undef,
  $backup_time_hour = undef,
  $backup_time_weekday = undef,
  $backup_time_dom = undef,
  $cmd_preexec = undef,
  $cmd_postexec = undef,
  $retain_hourly = undef,
  $retain_daily = undef,
  $retain_weekly = undef,
  $retain_monthly = undef,
  $one_fs = undef,
  $rsync_short_args = undef,
  $rsync_long_args = undef,
  $ssh_args = undef,
  $wrapper_path = undef,
  $du_args = undef,
  $use_sudo = undef,
  $wrapper_sudo = $rsnapshot::params::wrapper_sudo,
  $wrapper_rsync_sender = $rsnapshot::params::wrapper_rsync_sender,
  $wrapper_rsync_ssh = $rsnapshot::params::wrapper_rsync_ssh,
  ) {

  # Remove trailing slashes.
  $log_path_norm = regsubst($log_path, '\/$', '')
  $lock_path_norm = regsubst($lock_path, '\/$', '')
  $config_path_norm = regsubst($config_path, '\/$', '')
  $backup_path_norm = regsubst($backup_path, '\/$', '')
  $wrapper_path_norm = regsubst($wrapper_path, '\/$', '')

  $log_file = "${log_path_norm}/${name}-rsnapshot.log"
  $lock_file = "${lock_path_norm}/${name}-rsnapshot.pid"
  $config_file = "${config_path_norm}/${name}-rsnapshot.conf"
  $snapshot_root = "${backup_path_norm}/${name}"

  if($ssh_args) {
    $ssh_args_processed = "-e 'ssh ${ssh_args}'"
  } else {
    $ssh_args_processed = ''
  }

  if($use_sudo) {
    $rsync_wrapper_processed = "--rsync-path=\"${wrapper_path_norm}/${wrapper_sudo}\""
  } else {
    $rsync_wrapper_processed = "--rsync-path=\"${wrapper_path_norm}/${wrapper_rsync_ssh}\""
  }

  $rsync_long_args_final = "${ssh_args_processed} ${rsync_long_args} ${rsync_wrapper_processed}"


  file { $snapshot_root :
    ensure  => directory,
    require => File[$backup_path]
  } ->

  file { $log_file :
    ensure  => present,
    require => File[$log_path]
  } ->

  # cronjobs

  ## hourly
  cron { "rsnapshot-${name}-hourly" :
    command => "${rsnapshot::server::cmd_rsnapshot} -c ${config_file} hourly",
    user    => 'root',
    hour    => $backup_hourly_cron,
    minute  => $backup_time_minute
  } ->

  ## daily
  cron { "rsnapshot-${name}-daily" :
    command => "${rsnapshot::server::cmd_rsnapshot} -c ${config_file} daily",
    user    => 'root',
    hour    => $backup_time_hour,
    minute  => $backup_time_minute
  } ->

  ## weekly
  cron { "rsnapshot-${name}-weekly" :
    command => "${rsnapshot::server::cmd_rsnapshot} -c ${config_file} weekly",
    user    => 'root',
    hour    => ($backup_time_hour + 3) % 24,
    minute  => $backup_time_minute,
    weekday => $backup_time_weekday
  } ->

  ## monthly
  cron { "rsnapshot-${name}-monthly" :
    command  => "${rsnapshot::server::cmd_rsnapshot} -c ${config_file} monthly",
    user     => 'root',
    hour     => ($backup_time_hour + 6) % 24,
    minute   => $backup_time_minute,
    monthday => $backup_time_dom
  }

  $programs = {
    cmd_cp => $rsnapshot::server::cmd_cp,
    cmd_rm => $rsnapshot::server::cmd_rm,
    cmd_rsync => $rsnapshot::server::cmd_rsync,
    cmd_ssh => $rsnapshot::server::cmd_ssh,
    cmd_logger => $rsnapshot::server::cmd_logger,
    cmd_du => $rsnapshot::server::cmd_du,
    cmd_rsnapshot_diff => $rsnapshot::server::cmd_rsnapshot_diff,
    linux_lvm_cmd_lvcreate => $rsnapshot::server::linux_lvm_cmd_lvcreate,
    linux_lvm_cmd_lvremove => $rsnapshot::server::linux_lvm_cmd_lvremove,
    linux_lvm_cmd_mount => $rsnapshot::server::linux_lvm_cmd_mount,
    linux_lvm_cmd_umount => $rsnapshot::server::linux_lvm_cmd_umount,
  }

  $options = {
    lockfile => $lock_file,
    logfile => $log_file,
    no_create_root => $no_create_root,
    verbose => $verbose,
    loglevel => $log_level,
    link_dest => $link_dest,
    sync_first => $sync_first,
    use_lazy_deletes => $use_lazy_deletes,
    rsync_numtries => $rsync_numtries,
    stop_on_stale_lockfile => $stop_on_stale_lockfile,
    cmd_preexec => $cmd_preexec,
    cmd_postexec => $cmd_postexec,
    one_fs => $one_fs,
    rsync_short_args => $rsync_short_args,
    rsync_long_args => $rsync_long_args_final,
    du_args => $du_args,
  }

  $lockfile = "${rsnapshot::server::lock_path}${name}"
  $logfile = "${rsnapshot::server::log_path}${name}"

  # config file
  concat { $config_file :
    owner => $::rsnapshot::server::user,
    group => $::rsnapshot::server::user,
    mode  => '0644',
    warn  => true
  }

  concat::fragment { "${config_file}_header" :
    target  => $config_file,
    content => template('rsnapshot/config.erb'),
    order   => 01
  }

  Rsnapshot::Server::Backup_config <<| host == $name |>> {
    config_file => $config_file
  }

}
