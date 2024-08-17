{ config, pkgs, ... }:

# TODO: this is broken, I put the disk in and it doesn't rip. IntelQSV transcoding doesn't work, and MakeMKV doesn't work.
# here are some errors

# ARM: [ARM] Entering docker wrapper
# ARM: [ARM] Starting ARM for DVD on sr0
# DEBUG ARM: json_api.process_logfile active
# DEBUG ARM: json_api.process_logfile using handbrake
# DEBUG ARM: json_api.process_handbrake_logfile Cant find index
# DEBUG ARM: json_api.get_x_jobs couldn't get config
# DEBUG ARM: json_api.get_x_jobs jobs  - we have 1 jobs
# DEBUG ARM: json_api.process_logfile active
# DEBUG ARM: json_api.process_logfile using handbrake
# DEBUG ARM: utils.database_updater Setting seen: 1
# DEBUG ARM: utils.database_updater Setting dismiss_time: 2024-06-27 15:29:23.024599
# DEBUG ARM: utils.database_updater successfully written to the database
# DEBUG ARM: json_api.process_logfile ripping
# DEBUG ARM: json_api.process_logfile using mkv - /home/arm/logs/THE_MAGNIFICENT_SEVEN_2016_171950215159.log
# tail: cannot open '/home/arm/logs/progress/2.log' for reading: No such file or directory
# DEBUG ARM: json_api.read_log_line Error while reading logfile for ETA
# DEBUG ARM: json_api.get_x_jobs jobs  - we have 1 jobs
# ARM: eject: device name is `/dev/sr0'
# ARM: eject: expanded name is `/dev/sr0'
# ARM: eject: `/dev/sr0' is not mounted
# ARM: eject: `/dev/sr0' is not a mount point
# ARM: eject: `/dev/sr0' is not a multipartition device
# ARM: eject: trying to eject `/dev/sr0' using SCSI commands
# ARM: eject: SCSI eject succeeded
# ARM: [ARM] Entering docker wrapper
# ARM: [ARM] Not CD, Blu-ray, DVD or Data. Bailing out on sr0

# INFO ARM: ARM version: 2.6.67
# INFO ARM: Python version: 3.8.10 (default, Nov 22 2023, 10:22:35) 
# INFO ARM: User is: arm
# INFO ARM: Alembic head is: 469d88477c13
# INFO ARM: Database version is: 469d88477c13
# INFO ARM: ************* Starting ARM processing at 2024-06-27 15:25:29.780333 *************
# INFO ARM: Looking for log files older than 1 days old.
# INFO ARM: Checking path /home/arm/logs/ for old log files...
# INFO ARM: Checking path /home/arm/logs/progress for old log files...
# INFO ARM: Job: THE_MAGNIFICENT_SEVEN_2016
# INFO ARM: Job #1 with PID 280 is currently running.
# INFO ARM: Starting Disc identification
# INFO ARM: Mounting disc to: /mnt/dev/sr0
# INFO ARM: Mounting disc was successful
# INFO ARM: Disc identified as video
# INFO ARM: DVD CRC64 hash is: a42e0ff7ce30e73f
# INFO ARM: Disc title Post ident -  title:The-Magnificent-Seven year:2016 video_type:movie disctype: dvd
# INFO ARM: We have no previous rips/jobs matching this label
# INFO ARM: Waiting 60 seconds for manual override.
# INFO ARM: ******************* Logging ARM variables *******************
# INFO ARM: devpath: /dev/sr0
# INFO ARM: mountpoint: /mnt/dev/sr0
# INFO ARM: title: The-Magnificent-Seven
# INFO ARM: year: 2016
# INFO ARM: video_type: movie
# INFO ARM: hasnicetitle: True
# INFO ARM: label: THE_MAGNIFICENT_SEVEN_2016
# INFO ARM: disctype: dvd
# INFO ARM: ******************* End of ARM variables *******************
# INFO ARM: ******************* Logging config parameters *******************
# INFO ARM: skip_transcode: False
# INFO ARM: mainfeature: False
# INFO ARM: minlength: 600
# INFO ARM: maxlength: 99999
# INFO ARM: videotype: auto
# INFO ARM: manual_wait: True
# INFO ARM: manual_wait_time: 60
# INFO ARM: ripmethod: mkv
# INFO ARM: mkv_args: 
# INFO ARM: delrawfiles: True
# INFO ARM: hb_preset_dvd: HQ 720p30 Surround
# INFO ARM: hb_preset_bd: HQ 1080p30 Surround
# INFO ARM: hb_args_dvd: --subtitle scan -F
# INFO ARM: hb_args_bd: --subtitle scan -F --subtitle-burned --audio-lang-list eng --all-audio
# INFO ARM: raw_path: /home/arm/media/raw/
# INFO ARM: transcode_path: /home/arm/media/transcode/
# INFO ARM: completed_path: /home/arm/media/completed/
# INFO ARM: extras_sub: extras
# INFO ARM: emby_refresh: False
# INFO ARM: emby_server: 
# INFO ARM: emby_port: 8096
# INFO ARM: notify_rip: True
# INFO ARM: notify_transcode: True
# INFO ARM: max_concurrent_transcodes: 0
# INFO ARM: ******************* End of config parameters *******************
# INFO ARM: Checking for fstab entry.
# INFO ARM: fstab entry is: /dev/sr0  /mnt/dev/sr0  udf,iso9660  users,noauto,exec,utf8,ro  0  0
# INFO ARM: Final Output directory "/home/arm/media/transcode/movies/The-Magnificent-Seven (2016)"
# INFO ARM: Final Output directory "/home/arm/media/completed/movies/The-Magnificent-Seven (2016)"
# INFO ARM: Processing files to: /home/arm/media/transcode/movies/The-Magnificent-Seven (2016)
# INFO ARM: ************* Ripping disc with MakeMKV *************
# INFO ARM: Updating MakeMKV key...
# INFO ARM: Starting MakeMKV rip. Method is mkv
# ERROR ARM: Call to MakeMKV failed with code: 1 (b'')
# ERROR ARM: MakeMKV did not complete successfully.  Exiting ARM! Error: exceptions must derive from BaseException


# ERROR ARM: 
# Traceback (most recent call last):
#   File "/opt/arm/arm/ripper/makemkv.py", line 46, in makemkv
#     mdisc = subprocess.check_output(
#   File "/usr/lib/python3.8/subprocess.py", line 415, in check_output
#     return run(*popenargs, stdout=PIPE, timeout=timeout, check=True,
#   File "/usr/lib/python3.8/subprocess.py", line 516, in run
#     raise CalledProcessError(retcode, process.args,
# subprocess.CalledProcessError: Command 'makemkvcon -r info disc:9999 | grep /dev/sr0 | grep -oP '(?<=:).*?(?=,)'' returned non-zero exit status 1.

# During handling of the above exception, another exception occurred:

# Traceback (most recent call last):
#   File "/opt/arm/arm/ripper/arm_ripper.py", line 53, in rip_visual_media
#     makemkv_out_path = makemkv.makemkv(logfile, job)
#   File "/opt/arm/arm/ripper/makemkv.py", line 53, in makemkv
#     raise MakeMkvRuntimeError(mdisc_error) from mdisc_error
#   File "/opt/arm/arm/ripper/makemkv.py", line 26, in __init__
#     raise super().__init__(self.message)
# TypeError: exceptions must derive from BaseException

# The above exception was the direct cause of the following exception:

# Traceback (most recent call last):
#   File "/opt/arm/arm/ripper/main.py", line 203, in <module>
#     main(log_file, job, args.protection)
#   File "/opt/arm/arm/ripper/main.py", line 110, in main
#     arm_ripper.rip_visual_media(have_dupes, job, logfile, protection)
#   File "/opt/arm/arm/ripper/arm_ripper.py", line 57, in rip_visual_media
#     raise ValueError from mkv_error
# ValueError
# ERROR ARM: A fatal error has occurred and ARM is exiting.  See traceback below for details.


# Docker run command:
# docker run -d \
#    -p "8080:8080" \
#    -e ARM_UID="1002" \
#    -e ARM_GID="983" \
#    -v "/home/arm:/home/arm" \
#    -v "/home/arm/Music:/home/arm/Music" \
#    -v "/home/arm/logs:/home/arm/logs" \
#    -v "/home/arm/media:/home/arm/media" \
#    -v "/home/arm/config:/etc/arm/config" \
#    --device=/dev/sr0:/dev/sr0 \
#    --privileged \
#    --restart "always" \
#    --name "arm-rippers" \
#    1337server/automatic-ripping-machine:latest

{
  networking.firewall.allowedTCPPorts = [ 9090 ];
  virtualisation.oci-containers.containers."arm-rippers" = {
    autoStart = true; # Assuming you want the container to start automatically on boot
    image = "automaticrippingmachine/automatic-ripping-machine:latest";
    ports = [ "9090:8080" ]; #TODO: Change the port to something other than 8080, might have to change env var also
    environment = {
      ARM_UID = "1002";
      ARM_GID = "983";
    };
    volumes = [
      "/home/arm:/home/arm"
      "/home/arm/Music:/home/arm/Music"
      "/home/arm/logs:/home/arm/logs"
      "/home/arm/media:/home/arm/media"
      "/home/arm/config:/etc/arm/config"
    ];
    extraOptions = [
      "--device=/dev/sr0:/dev/sr0"
      "--privileged"
    ];
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.arm = {
    isNormalUser = true;
    description = "arm";
    group = "arm";
    extraGroups = [ "arm" "cdrom" "video" "docker" ];
    hashedPassword = "$y$j9T$2gGzaHfv1JMUMtHdaXBGF/$RoEaBINI46v1yFpR1bSgPc9ovAyzqjgSSTxuNhRiOn4";
  };

  users.groups.arm = { };

  # Enable udev
  services.udev.enable = true;

}
