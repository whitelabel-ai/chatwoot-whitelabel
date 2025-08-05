<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import BillingAPI from 'dashboard/api/billing';

const props = defineProps({
  show: {
    type: Boolean,
    required: true,
  },
  transaction: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['close']);

const { t } = useI18n();
const { showAlert } = useAlert();

const downloadingInvoice = ref(false);

const getStatusColor = status => {
  const colors = {
    successful: 'success',
    pending: 'warning',
    failed: 'error',
  };
  return colors[status] || 'secondary';
};

const getStatusText = status => {
  if (!status) return '';
  const statusKey = `BILLING.STATUS.${status.toUpperCase()}`;
  // eslint-disable-next-line @intlify/vue-i18n/no-dynamic-keys
  return t(statusKey);
};

const formatDate = dateString => {
  return new Date(dateString).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
};

const formatNumber = number => {
  return new Intl.NumberFormat().format(number);
};

const downloadInvoice = async () => {
  downloadingInvoice.value = true;

  try {
    const response = await BillingAPI.downloadInvoice(props.transaction.id);
    const url = window.URL.createObjectURL(new Blob([response]));
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', `invoice-${props.transaction.id}.pdf`);
    document.body.appendChild(link);
    link.click();
    link.remove();
    window.URL.revokeObjectURL(url);
  } catch (error) {
    showAlert(error.message || 'Failed to download invoice');
  } finally {
    downloadingInvoice.value = false;
  }
};

const onClose = () => {
  emit('close');
};
</script>

<template>
  <woot-modal :show="show" :on-close="onClose">
    <woot-modal-header
      :header-title="$t('BILLING.TRANSACTION_DETAILS.TITLE')"
      :header-content="
        $t('BILLING.TRANSACTION_DETAILS.TRANSACTION_ID', { id: transaction.id })
      "
    />

    <div class="p-6">
      <div class="space-y-6">
        <!-- Transaction Info -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1">
              {{ $t('BILLING.TRANSACTION_DETAILS.TRANSACTION_ID_LABEL') }}
            </label>
            <p class="text-lg font-mono text-slate-900">
              {{ $t('BILLING.TRANSACTION_DETAILS.ID_PREFIX')
              }}{{ transaction.id }}
            </p>
          </div>

          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1">
              {{ $t('BILLING.TRANSACTIONS.STATUS') }}
            </label>
            <woot-badge
              :color="getStatusColor(transaction.status)"
              :text="getStatusText(transaction.status)"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1">
              {{ $t('BILLING.TRANSACTIONS.DATE') }}
            </label>
            <p class="text-lg text-slate-900">
              {{ formatDate(transaction.created_at) }}
            </p>
          </div>

          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1">
              {{ $t('BILLING.TRANSACTIONS.AMOUNT') }}
            </label>
            <p class="text-lg font-semibold text-slate-900">
              {{ $t('BILLING.CURRENCY_SYMBOL') }}{{ transaction.amount }}
            </p>
          </div>
        </div>

        <!-- Plan Details -->
        <div v-if="transaction.billing_plan" class="border-t pt-6">
          <h3 class="text-lg font-semibold text-slate-900 mb-4">
            {{ $t('BILLING.TRANSACTION_DETAILS.PLAN_DETAILS') }}
          </h3>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1">
                {{ $t('BILLING.TRANSACTIONS.PLAN') }}
              </label>
              <p class="text-lg text-slate-900">
                {{ transaction.billing_plan.name }}
              </p>
            </div>

            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1">
                {{ $t('BILLING.PLANS.MESSAGE_LIMIT') }}
              </label>
              <p class="text-lg text-slate-900">
                {{ formatNumber(transaction.billing_plan.message_limit) }}
                {{ $t('BILLING.PLANS.MESSAGES_PER_MONTH') }}
              </p>
            </div>

            <div v-if="transaction.billing_plan.description">
              <label class="block text-sm font-medium text-slate-700 mb-1">
                {{ $t('BILLING.PLANS.DESCRIPTION') }}
              </label>
              <p class="text-sm text-slate-600">
                {{ transaction.billing_plan.description }}
              </p>
            </div>
          </div>
        </div>

        <!-- Payment Details -->
        <div class="border-t pt-6">
          <h3 class="text-lg font-semibold text-slate-900 mb-4">
            {{ $t('BILLING.TRANSACTION_DETAILS.PAYMENT_DETAILS') }}
          </h3>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1">
                {{ $t('BILLING.TRANSACTIONS.PAYMENT_METHOD') }}
              </label>
              <p class="text-lg text-slate-900">
                {{ transaction.payment_method || 'Online Payment' }}
              </p>
            </div>

            <div v-if="transaction.payment_gateway">
              <label class="block text-sm font-medium text-slate-700 mb-1">
                {{ $t('BILLING.TRANSACTION_DETAILS.PAYMENT_GATEWAY') }}
              </label>
              <p class="text-lg text-slate-900">
                {{ transaction.payment_gateway }}
              </p>
            </div>

            <div v-if="transaction.external_transaction_id">
              <label class="block text-sm font-medium text-slate-700 mb-1">
                {{ $t('BILLING.TRANSACTION_DETAILS.EXTERNAL_ID') }}
              </label>
              <p class="text-sm font-mono text-slate-600">
                {{ transaction.external_transaction_id }}
              </p>
            </div>

            <div v-if="transaction.payment_url">
              <label class="block text-sm font-medium text-slate-700 mb-1">
                {{ $t('BILLING.TRANSACTION_DETAILS.PAYMENT_URL') }}
              </label>
              <a
                :href="transaction.payment_url"
                target="_blank"
                rel="noopener noreferrer"
                class="text-sm text-blue-600 hover:text-blue-800 underline"
              >
                {{ $t('BILLING.TRANSACTION_DETAILS.VIEW_PAYMENT') }}
              </a>
            </div>
          </div>
        </div>

        <!-- Additional Info -->
        <div
          v-if="transaction.notes || transaction.metadata"
          class="border-t pt-6"
        >
          <h3 class="text-lg font-semibold text-slate-900 mb-4">
            {{ $t('BILLING.TRANSACTION_DETAILS.ADDITIONAL_INFO') }}
          </h3>

          <div v-if="transaction.notes" class="mb-4">
            <label class="block text-sm font-medium text-slate-700 mb-1">
              {{ $t('BILLING.TRANSACTION_DETAILS.NOTES') }}
            </label>
            <p class="text-sm text-slate-600 bg-slate-50 p-3 rounded">
              {{ transaction.notes }}
            </p>
          </div>

          <div
            v-if="
              transaction.metadata &&
              Object.keys(transaction.metadata).length > 0
            "
          >
            <label class="block text-sm font-medium text-slate-700 mb-1">
              {{ $t('BILLING.TRANSACTION_DETAILS.METADATA') }}
            </label>
            <div class="bg-slate-50 p-3 rounded">
              <pre class="text-xs text-slate-600 whitespace-pre-wrap">{{
                JSON.stringify(transaction.metadata, null, 2)
              }}</pre>
            </div>
          </div>
        </div>

        <!-- Timeline -->
        <div class="border-t pt-6">
          <h3 class="text-lg font-semibold text-slate-900 mb-4">
            {{ $t('BILLING.TRANSACTION_DETAILS.TIMELINE') }}
          </h3>
          <div class="space-y-3">
            <div class="flex items-center space-x-3">
              <div class="w-2 h-2 bg-blue-500 rounded-full" />
              <div>
                <p class="text-sm font-medium text-slate-900">
                  {{ $t('BILLING.TRANSACTION_DETAILS.CREATED') }}
                </p>
                <p class="text-xs text-slate-600">
                  {{ formatDate(transaction.created_at) }}
                </p>
              </div>
            </div>

            <div
              v-if="transaction.updated_at !== transaction.created_at"
              class="flex items-center space-x-3"
            >
              <div class="w-2 h-2 bg-green-500 rounded-full" />
              <div>
                <p class="text-sm font-medium text-slate-900">
                  {{ $t('BILLING.TRANSACTION_DETAILS.LAST_UPDATED') }}
                </p>
                <p class="text-xs text-slate-600">
                  {{ formatDate(transaction.updated_at) }}
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="flex justify-between p-6 border-t border-slate-200">
      <div>
        <woot-button
          v-if="transaction.status === 'successful'"
          color-scheme="primary"
          :loading="downloadingInvoice"
          @click="downloadInvoice"
        >
          {{ $t('BILLING.BUTTONS.DOWNLOAD_INVOICE') }}
        </woot-button>
      </div>

      <woot-button color-scheme="secondary" @click="onClose">
        {{ $t('BILLING.BUTTONS.CLOSE') }}
      </woot-button>
    </div>
  </woot-modal>
</template>
