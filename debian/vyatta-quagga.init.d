#!/bin/bash
#
### BEGIN INIT INFO
# Provides: vyatta-quagga
# Required-Start: $local_fs $network $remote_fs $syslog
# Required-Stop: $local_fs $network $remote_fs $syslog
# Default-Start:  2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: start and stop the Quagga routing suite
# Description: Quagga is a routing suite for IP routing protocols like 
#              BGP, OSPF, RIP and others. This script contols the main 
#              daemon "quagga" as well as the individual protocol daemons.
#              FIXME! this init script will be deprecated as daemon start/stop
#                     is integrated with vyatta-cfg-quagga
### END INIT INFO
#

. /lib/lsb/init-functions

declare progname=${0##*/}
declare action=$1; shift

pid_dir=/var/run/vyatta/quagga
log_dir=/var/log/vyatta/quagga

for dir in $pid_dir $log_dir ; do
    if [ ! -d $dir ]; then
	mkdir -p $dir
	chown quagga:quagga $dir
	chmod 755 $dir
    fi
done

declare -a common_args=( -d -P 0 )
declare -a zebra_args=( ${common_args[@]} -l -S -s 1048576 -i $pid_dir/zebra.pid )
declare -a ripd_args=( ${common_args[@]} -i $pid_dir/ripd.pid )
declare -a ripngd_args=( ${common_args[@]} -i $pid_dir/ripngd.pid )
declare -a ospfd_args=( ${common_args[@]} -i $pid_dir/ospfd.pid )
declare -a ospf6d_args=( ${common_args[@]} -i $pid_dir/ospf6d.pid )
declare -a isisd_args=( ${common_args[@]} -i $pid_dir/isisd.pid )
declare -a bgpd_args=( ${common_args[@]} -i $pid_dir/bgpd.pid )

vyatta_quagga_start ()
{
    local -a daemons
    if [ $# -gt 0 ] ; then
	daemons=( $* )
    else
	daemons+=( zebra )
	daemons+=( ripd )
	daemons+=( ripngd )
	daemons+=( ospfd )
	daemons+=( ospf6d )
#	daemons+=( isisd )
	daemons+=( bgpd )
    fi

    log_action_begin_msg "Starting Quagga"
    for daemon in ${daemons[@]} ; do
	[ "$daemon" != zebra ] && \
	    log_action_cont_msg "$daemon"
	start-stop-daemon \
	    --start \
	    --quiet \
	    --oknodo \
	    --pidfile=$pid_dir/${daemon}.pid \
	    --chdir $log_dir \
	    --exec "/usr/sbin/vyatta-${daemon}" \
	    -- `eval echo "$""{${daemon}_args[@]}"` || \
	    ( log_action_end_msg 1 ; return 1 )
    done
    log_action_end_msg 0
}

vyatta_quagga_stop ()
{
    local -a daemons

    if [ $# -gt 0 ] ; then
	daemons=( $* )
    else
	daemons=( bgpd isisd ospf6d ospfd ripngd ripd zebra )
    fi
    log_action_begin_msg "Stopping Quagga"
    for daemon in ${daemons[@]} ; do
	pidfile=$pid_dir/${daemon}.pid
	[ "$daemon" != zebra ] && \
		log_action_cont_msg "$daemon"
	if [ -r $pidfile ]; then
	    start-stop-daemon --stop --quiet --retry=TERM/30/KILL/5 \
		--pidfile $pidfile --name vyatta-$daemon
	    rm -f $pidfile
	fi
	# wait for any children as well
	start-stop-daemon \
	    --stop --quiet --oknodo \
	    --retry=0/30/KILL/5  --exec /usr/sbin/vyatta-${daemon}
    done
    log_action_end_msg $?
    if echo ${daemons[@]} | grep -q zebra ; then
	log_begin_msg "Removing all Quagga Routes"
	ip route flush proto zebra
	log_end_msg $?
    fi
}

case "$action" in
    start)
	vyatta_quagga_start $*
    	;;
	
    stop|0)
	vyatta_quagga_stop $*
   	;;

    restart|force-reload)
	vyatta_quagga_stop $*
	sleep 2
	vyatta_quagga_start $*
	;;

    *)
    	echo "Usage: $progname {start|stop|restart|force-reload} [daemon...]"
	exit 1
	;;
esac
