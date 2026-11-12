# Integración blockchain de GIAPESA

La aplicación puede enviar transacciones a una red EVM mediante una wallet inyectada, como MetaMask. El contrato de referencia está en `contracts/GiapesaEscrow.sol` y custodia un token ERC-20: crea acuerdos, define hitos, registra depósitos, ancla hashes SHA-256 y paga al subcontratista cuando dos de los tres aprobadores autorizan un hito.

## Acceso al prototipo

En el primer acceso se crea el usuario administrador local; después se ingresa con ese usuario y contraseña. La contraseña se guarda como hash PBKDF2 en el almacenamiento del navegador y la sesión dura mientras permanezca abierta esa pestaña. Este control no es autenticación multiusuario de servidor: los datos de negocio también están en el navegador. Para producción, reemplázalo por un backend con sesiones seguras, recuperación de cuenta, control de roles y almacenamiento protegido.

## Despliegue de prueba

1. Usa una testnet EVM, una wallet de pruebas y un token ERC-20 de prueba. No uses fondos ni llaves de producción.
2. Abre `contracts/GiapesaEscrow.sol` en Remix, selecciona Solidity `0.8.24` o compatible con `^0.8.24`, compila y revisa el resultado antes de desplegar.
3. Despliega `GiapesaEscrow` con el token ERC-20 de esa red y tres direcciones de aprobadores distintas. El deployer será el administrador; no puede ser uno de los aprobadores.
4. Sirve esta carpeta en `http://localhost` o HTTPS y abre `index.html`. Una página `file://` puede impedir que MetaMask inyecte la wallet.
5. En **Blockchain**, configura el chain ID, la dirección del escrow, la dirección del token y sus decimales. El valor inicial de chain ID es Sepolia (`11155111`). Guarda y conecta MetaMask en la misma red.
6. El administrador registra acuerdos e hitos y fondea el escrow. Cada depósito requiere dos confirmaciones: autorización ERC-20 y depósito.
7. El subcontratista o administrador sube una evidencia asociada al hito. La aplicación calcula SHA-256 y publica únicamente ese hash; el archivo y la ubicación GPS no se escriben en la cadena.
8. Cada uno de los tres aprobadores conecta su propia wallet y firma el hito. La segunda firma ejecuta la transferencia ERC-20 dentro de la misma transacción.

Los montos enviados al contrato son unidades del token configurado, no dólares convertidos automáticamente. La app consulta y valida sus decimales. El contrato exige un ERC-20 estándar que devuelva `bool` y no contempla tokens con comisión de transferencia.

## Límites de esta entrega

- Esta es una integración EVM para pruebas; el contrato no ha sido compilado ni auditado en este entorno. Requiere revisión y pruebas independientes antes de cualquier despliegue con valor real.
- El prototipo no integra Oracle, HSM, backend de notificaciones, almacenamiento de archivos ni sincronización automática del historial desde la cadena. Los datos descriptivos y la relación entre IDs se guardan en el almacenamiento local del navegador; conserva ese perfil para consultar los acuerdos creados desde la interfaz.
- Los tres aprobadores se fijan al desplegar el contrato. No existe todavía flujo de rechazo, disputa, cambio de firmantes ni recuperación administrativa.
- Las direcciones de transacción se enlazan a exploradores configurados para Sepolia, Base Sepolia y Polygon Amoy; en otras redes se muestra el hash sin enlace.
- El contrato publica en eventos el identificador, montos, nombres/condiciones de hitos y hashes de evidencias. No publiques información personal ni coordenadas sensibles en estos campos.