#!/bin/bash

# 防火墙管理脚本，支持 firewalld 和 iptables

# 检测防火墙类型
if systemctl is-active --quiet firewalld; then
    FW_TYPE="firewalld"
elif command -v iptables >/dev/null 2>&1; then
    FW_TYPE="iptables"
else
    echo "未检测到 firewalld 或 iptables，无法管理防火墙。"
    exit 1
fi

add_port() {
    PORT=$1
    PROTO=$2
    if [ "$FW_TYPE" = "firewalld" ]; then
        firewall-cmd --permanent --add-port=${PORT}/${PROTO}
        firewall-cmd --reload
        echo "[firewalld] 已添加端口 ${PORT}/${PROTO}"
    else
        iptables -C INPUT -p $PROTO --dport $PORT -j ACCEPT 2>/dev/null || \
        iptables -A INPUT -p $PROTO --dport $PORT -j ACCEPT
        service iptables save 2>/dev/null || iptables-save > /etc/iptables/rules.v4 2>/dev/null
        echo "[iptables] 已添加端口 ${PORT}/${PROTO}"
    fi
}

remove_port() {
    PORT=$1
    PROTO=$2
    if [ "$FW_TYPE" = "firewalld" ]; then
        firewall-cmd --permanent --remove-port=${PORT}/${PROTO}
        firewall-cmd --reload
        echo "[firewalld] 已移除端口 ${PORT}/${PROTO}"
    else
        iptables -D INPUT -p $PROTO --dport $PORT -j ACCEPT 2>/dev/null
        service iptables save 2>/dev/null || iptables-save > /etc/iptables/rules.v4 2>/dev/null
        echo "[iptables] 已移除端口 ${PORT}/${PROTO}"
    fi
}

list_rules() {
    if [ "$FW_TYPE" = "firewalld" ]; then
        firewall-cmd --list-all
    else
        iptables -L -n -v
    fi
}

fw_start() {
    if [ "$FW_TYPE" = "firewalld" ]; then
        systemctl start firewalld
    else
        systemctl start iptables 2>/dev/null || service iptables start
    fi
    echo "防火墙已启动"
}

fw_stop() {
    if [ "$FW_TYPE" = "firewalld" ]; then
        systemctl stop firewalld
    else
        systemctl stop iptables 2>/dev/null || service iptables stop
    fi
    echo "防火墙已停止"
}

fw_restart() {
    if [ "$FW_TYPE" = "firewalld" ]; then
        systemctl restart firewalld
    else
        systemctl restart iptables 2>/dev/null || service iptables restart
    fi
    echo "防火墙已重启"
}

fw_status() {
    if [ "$FW_TYPE" = "firewalld" ]; then
        systemctl status firewalld
    elif systemctl status netfilter-persistent >/dev/null 2>&1; then
        systemctl status netfilter-persistent
    elif service netfilter-persistent status >/dev/null 2>&1; then
        service netfilter-persistent status
    elif service iptables status >/dev/null 2>&1; then
        service iptables status
    else
        echo "未检测到防火墙服务，直接显示 iptables 规则："
        iptables -L -n -v
    fi
}

check_status() {
    if [ "$FW_TYPE" = "firewalld" ]; then
        if systemctl is-active --quiet firewalld; then
            echo "[firewalld] 状态：已启动"
        else
            echo "[firewalld] 状态：已停止"
        fi
    else
        if systemctl is-active --quiet iptables 2>/dev/null || service iptables status >/dev/null 2>&1; then
            echo "[iptables] 状态：已启动"
        else
            echo "[iptables] 状态：已停止"
        fi
    fi
}

show_help() {
    echo "用法: $0 <命令> [参数]"
    echo "命令:"
    echo "  add <端口> <tcp|udp>      添加端口规则"
    echo "  remove <端口> <tcp|udp>   移除端口规则"
    echo "  list                     查看当前规则"
    echo "  start                    启动防火墙"
    echo "  stop                     停止防火墙"
    echo "  restart                  重启防火墙"
    echo "  status                   查看防火墙状态"
    echo "  check                    检查防火墙是否已启动/已停止"
    echo "  help                     显示帮助信息"
}

case "$1" in
    add)
        add_port "$2" "$3"
        ;;
    remove)
        remove_port "$2" "$3"
        ;;
    list)
        list_rules
        ;;
    start)
        fw_start
        ;;
    stop)
        fw_stop
        ;;
    restart)
        fw_restart
        ;;
    status)
        fw_status
        ;;
    check)
        check_status
        ;;
    help|*)
        show_help
        ;;
esac
