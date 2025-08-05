# Sistema de Facturación para Chatwoot

Este documento describe el sistema de facturación implementado para Chatwoot, que permite gestionar planes de facturación, suscripciones de cuentas y consumo de mensajes.

## Características Principales

### 1. Gestión de Planes de Facturación
- Planes personalizables con límites de mensajes mensuales
- Precios flexibles en diferentes monedas
- Características configurables (auto-renovación, soporte, acceso API)
- Plan gratuito por defecto

### 2. Suscripciones de Cuentas
- Asociación automática de cuentas a planes de facturación
- Seguimiento del uso de mensajes
- Estados de suscripción (activa, suspendida, cancelada)
- Renovación automática de períodos

### 3. Transacciones de Facturación
- Registro de todas las transacciones de pago
- Estados de transacción (pendiente, exitosa, fallida)
- Soporte para múltiples tipos de transacción

### 4. Registro de Consumo de Mensajes
- Auditoría completa del uso de mensajes
- Registro por cuenta, conversación y mensaje
- Reportes de consumo por período

## Modelos Implementados

### BillingPlan
- `name`: Nombre del plan
- `monthly_message_limit`: Límite mensual de mensajes
- `price`: Precio del plan
- `currency`: Moneda del precio
- `features`: Características del plan (JSON)
- `active`: Estado del plan

### AccountSubscription
- `account_id`: Referencia a la cuenta
- `billing_plan_id`: Referencia al plan de facturación
- `status`: Estado de la suscripción
- `messages_limit`: Límite de mensajes para esta suscripción
- `messages_used`: Mensajes utilizados en el período actual
- `current_period_start/end`: Período de facturación actual

### BillingTransaction
- `account_id`: Referencia a la cuenta
- `billing_plan_id`: Referencia al plan
- `transaction_id`: ID único de la transacción
- `transaction_type`: Tipo de transacción
- `amount`: Monto de la transacción
- `currency`: Moneda de la transacción
- `status`: Estado de la transacción

### MessageConsumptionLog
- `account_id`: Referencia a la cuenta
- `message_id`: Referencia al mensaje
- `conversation_id`: Referencia a la conversación
- `message_type`: Tipo de mensaje (entrante/saliente)
- `consumed_at`: Timestamp del consumo

## Controladores API

### Api::V1::Accounts::BillingController
Endpoints para gestión de facturación por cuenta:
- `GET /api/v1/accounts/:account_id/billing` - Detalles de suscripción
- `GET /api/v1/accounts/:account_id/billing/plans` - Planes disponibles
- `GET /api/v1/accounts/:account_id/billing/transactions` - Historial de transacciones
- `GET /api/v1/accounts/:account_id/billing/usage_report` - Reporte de uso
- `POST /api/v1/accounts/:account_id/billing/create_payment` - Crear pago
- `POST /api/v1/accounts/:account_id/billing/upgrade_plan` - Actualizar plan

### SuperAdmin::BillingController
Panel de administración para super administradores:
- Gestión de cuentas y suscripciones
- Administración de planes de facturación
- Reportes y análisis de facturación
- Herramientas de administración (suspender/activar cuentas)

## Servicios

### BillingService
Servicio principal para operaciones de facturación:
- `create_transaction`: Crear nueva transacción
- `process_successful_payment`: Procesar pago exitoso
- `upgrade_account_plan`: Actualizar plan de cuenta
- `reset_monthly_usage`: Reiniciar uso mensual
- `check_and_suspend_exceeded_accounts`: Verificar límites

## Integración con Modelos Existentes

### Account
Nuevos métodos agregados:
- `current_subscription`: Suscripción actual
- `current_plan`: Plan actual
- `messages_used_this_month`: Mensajes usados este mes
- `messages_remaining`: Mensajes restantes
- `can_send_messages?`: Verificar si puede enviar mensajes
- `consume_message!`: Consumir un mensaje
- `near_message_limit?`: Verificar si está cerca del límite

### Message
Nuevo callback agregado:
- `after_create_commit :consume_account_message`: Consumo automático de mensajes

## Rutas

### API Routes
```ruby
resource :billing, only: [:show], controller: 'billing' do
  collection do
    get :plans
    get :transactions
    get :usage_report
    get :alerts
    post :create_payment
    post :payment_callback
    post :upgrade_plan
  end
end
```

### Super Admin Routes
```ruby
namespace :billing do
  root to: 'billing#index'
  get :accounts
  resources :plans, path: 'billing_plans'
  # ... más rutas de administración
end
```

## Migración de Base de Datos

Se creó la migración `20241201000005_create_default_billing_plan.rb` que:
1. Crea las tablas necesarias
2. Inserta un plan gratuito por defecto
3. Establece las relaciones entre tablas

## Uso

### Para Desarrolladores
1. Las cuentas nuevas automáticamente obtienen una suscripción al plan gratuito
2. Los mensajes se consumen automáticamente al ser creados
3. El sistema verifica límites antes de permitir envío de mensajes

### Para Administradores
1. Acceder al panel de super admin
2. Navegar a la sección de billing
3. Gestionar planes, cuentas y transacciones

## Consideraciones de Seguridad

- Todas las operaciones de facturación requieren autenticación
- Los endpoints de super admin están protegidos por roles
- Las transacciones incluyen validaciones de integridad
- Los logs de consumo proporcionan auditoría completa

## Próximos Pasos

1. Implementar integración con pasarelas de pago
2. Agregar notificaciones por email para límites
3. Crear dashboard de analytics de facturación
4. Implementar descuentos y promociones
5. Agregar facturación automática recurrente