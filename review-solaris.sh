#!/bin/bash

echo "===== VERIFICACIONES DIARIAS SOLARIS ====="

# 1. VMs Activas
echo -e "\n--- Lista de VMs Activas y Puertos ---"
ldm ls | grep active | grep -v inactive | awk '{print $1 "    " $2 "    " $4}'

# 2. Verificar NRPE
echo -e "\n--- Estado del Servicio NRPE ---"
svcs -a nrpe | grep "online" > /dev/null
if [ $? -eq 0 ]; then
    echo "NRPE está activo (online)"
else
    echo "NRPE no está activo. Verificando dependencias..."
    svcs -D nrpe
    svcs -d nrpe
    echo "Ejecutando 'svcadm clear nrpe' para activar dependencias en mantenimiento"
    svcadm clear nrpe
fi

# 3. Verificar Alertas del Sistema
echo -e "\n--- Conteo de Alertas del Sistema ---"
alert_count=$(fmadm faulty | grep TIME | wc -l)
echo "Cantidad de alertas detectadas: $alert_count"

echo -e "\n--- Detalles de las Alertas del Sistema ---"
fmadm faulty

# Limpiar todas las alertas (Ejecutar con cuidado)
echo "¿Desea limpiar todas las alertas? (s/n)"
read -r response
if [[ "$response" == "s" ]]; then
    fmadm faulty | grep -A2 TIME | awk '$1 ~/^[A-Z]/ && $1 !~ /^TIME/ {system("fmadm clear "$4)}'
fi

# 4. Verificar Uso de CPU
echo -e "\n--- Estado de CPU (mpstat) ---"
mpstat 1 10 | awk '{print $1" -  "$16}'
echo -e "\nCPU con alto consumo (idle < 89%):"
mpstat 1 10 | awk '$16 < 89 {print}'

# 5. Verificar Uso de Memoria RAM
echo -e "\n--- Estado de Memoria RAM (vmstat) ---"
vmstat 1 10 | awk '{print $12}'
vmstat 1 10 | xargs date

# 6. Verificar I/O de Discos
echo -e "\n--- Estado de I/O de Discos (iostat) ---"
iostat -cnx 1 10 | awk '{print $8" - "$9" - "$10" - "$11}'
iostat -cnx 1 | awk '$8 > 0 {print}'

# 7. Estado de Organización de Memoria (Anon)
echo -e "\n--- Organización de Memoria (Anon) ---"
anon_usage=$(echo "::memstat" | mdb -k | grep "Anon" | awk '{print $2}' | sed 's/%//')
if [ "$anon_usage" -gt 80 ]; then
    echo "Anon está por encima del 80% ($anon_usage%) - Reportar al cliente."
elif [ "$anon_usage" -gt 60 ]; then
    echo "Anon está por encima del 60% ($anon_usage%) - Anotar en observaciones."
else
    echo "Anon está en un nivel aceptable ($anon_usage%)."
fi

# 8. Estado de ZPOOL
echo -e "\n--- Estado de ZPOOL ---"
zpool status | grep -i "errors"
if [ $? -ne 0 ]; then
    echo "No se encontraron errores en ZPOOL."
else
    echo "Se detectaron errores en ZPOOL. Detalles:"
    zpool status -v
    echo "Intentando corregir errores en dpool..."
    zpool scrub dpool
fi

# 9. Verificar Logs (Solo en Servidor Principal)
echo -e "\n--- Logs del Sistema (/var/adm/messages) ---"
echo "Últimos mensajes sin entradas de error LUNZ o Basis:"
cat /var/adm/messages | grep -v "LUNZ" | grep -v "Basis"
echo "Últimos mensajes en /var/adm/messages.0 sin entradas de error LUNZ o Basis:"
cat /var/adm/messages.0 | grep -v "LUNZ" | grep -v "Basis"

echo -e "\n===== FIN DE VERIFICACIONES ====="
