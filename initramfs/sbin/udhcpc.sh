#!/bin/busybox sh
# udhcpc script edited by Tim Riker <Tim@Rikers.org>

RESOLV_CONF="/etc/resolv.conf"


[ -n "$1" ] || { echo "Error: should be called from udhcpc"; exit 1; }

NETMASK=""
[ -n "$subnet" ] && NETMASK="netmask $subnet"
BROADCAST="broadcast +"
[ -n "$broadcast" ] && BROADCAST="broadcast $broadcast"

case "$1" in
	deconfig)
		echo "Setting IP address 0.0.0.0 on $interface"
		ifconfig $interface 0.0.0.0
		;;

	renew|bound)
		echo "Setting IP address $ip on $interface"
		ifconfig $interface $ip $NETMASK $BROADCAST

		if [ -n "$router" ] ; then
			echo "Deleting routers"
			while route del default gw 0.0.0.0 dev $interface ; do
				:
			done

			metric=0
			for i in $router ; do
				echo "Adding router $i"
				route add default gw $i dev $interface metric $((metric++))
			done
		fi

		echo "Recreating $RESOLV_CONF"
		echo -n > $RESOLV_CONF-$$
		[ -n "$domain" ] && echo "search $domain" >> $RESOLV_CONF-$$
		for i in $dns ; do
			echo " Adding DNS server $i"
			echo "nameserver $i" >> $RESOLV_CONF-$$
		done
		mv $RESOLV_CONF-$$ $RESOLV_CONF
		;;
esac

exit 0

