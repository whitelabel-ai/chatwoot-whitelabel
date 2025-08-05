<script setup>
import { ref, reactive, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import BillingAPI from 'dashboard/api/billing';
import TransactionDetailsModal from './TransactionDetailsModal.vue';

defineProps({
  show: {
    type: Boolean,
    required: true,
  },
});

const emit = defineEmits(['close']);

const { t } = useI18n();
const { showAlert } = useAlert();

const loading = ref(false);
const transactions = ref([]);
const downloadingInvoices = ref([]);
const selectedTransaction = ref(null);

const filters = reactive({
  status: '',
  dateRange: '',
  page: 1,
});

const pagination = reactive({
  current_page: 1,
  total_pages: 1,
  total_count: 0,
});

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
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
};

const fetchTransactions = async () => {
  loading.value = true;

  try {
    const params = {
      page: filters.page,
      per_page: 20,
    };

    if (filters.status) params.status = filters.status;
    if (filters.dateRange) params.date_range = filters.dateRange;

    const response = await BillingAPI.getTransactions(params);

    transactions.value = response.transactions || [];
    Object.assign(pagination, response.pagination || {});
  } catch (error) {
    showAlert(error.message || 'Failed to load transactions');
  } finally {
    loading.value = false;
  }
};

const resetFilters = () => {
  filters.status = '';
  filters.dateRange = '';
  filters.page = 1;
  fetchTransactions();
};

const changePage = page => {
  filters.page = page;
  fetchTransactions();
};

const downloadInvoice = async transactionId => {
  downloadingInvoices.value.push(transactionId);

  try {
    const response = await BillingAPI.downloadInvoice(transactionId);
    const url = window.URL.createObjectURL(new Blob([response]));
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', `invoice-${transactionId}.pdf`);
    document.body.appendChild(link);
    link.click();
    link.remove();
    window.URL.revokeObjectURL(url);
  } catch (error) {
    showAlert(error.message || 'Failed to download invoice');
  } finally {
    downloadingInvoices.value = downloadingInvoices.value.filter(
      id => id !== transactionId
    );
  }
};

const viewTransactionDetails = transaction => {
  selectedTransaction.value = transaction;
};

const onClose = () => {
  emit('close');
};

onMounted(() => {
  fetchTransactions();
});
</script>

<template>
  <woot-modal :show="show" :on-close="onClose" size="large">
    <woot-modal-header
      :header-title="$t('BILLING.TRANSACTIONS.TITLE')"
      :header-content="$t('BILLING.TRANSACTIONS.DESCRIPTION')"
    />

    <div class="p-6">
      <!-- Filters -->
      <div class="mb-6 flex flex-wrap gap-4">
        <div class="flex-1 min-w-48">
          <label class="block text-sm font-medium text-slate-700 mb-1">
            {{ $t('BILLING.TRANSACTIONS.STATUS') }}
          </label>
          <select
            v-model="filters.status"
            class="w-full px-3 py-2 border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            @change="fetchTransactions"
          >
            <option value="">{{ $t('BILLING.FILTERS.ALL_STATUSES') }}</option>
            <option value="successful">
              {{ $t('BILLING.STATUS.SUCCESSFUL') }}
            </option>
            <option value="pending">{{ $t('BILLING.STATUS.PENDING') }}</option>
            <option value="failed">{{ $t('BILLING.STATUS.FAILED') }}</option>
          </select>
        </div>

        <div class="flex-1 min-w-48">
          <label class="block text-sm font-medium text-slate-700 mb-1">
            {{ $t('BILLING.FILTERS.DATE_RANGE') }}
          </label>
          <select
            v-model="filters.dateRange"
            class="w-full px-3 py-2 border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            @change="fetchTransactions"
          >
            <option value="">{{ $t('BILLING.FILTERS.ALL_TIME') }}</option>
            <option value="last_month">
              {{ $t('BILLING.FILTERS.LAST_MONTH') }}
            </option>
            <option value="last_3_months">
              {{ $t('BILLING.FILTERS.LAST_3_MONTHS') }}
            </option>
            <option value="last_6_months">
              {{ $t('BILLING.FILTERS.LAST_6_MONTHS') }}
            </option>
            <option value="last_year">
              {{ $t('BILLING.FILTERS.LAST_YEAR') }}
            </option>
          </select>
        </div>

        <div class="flex items-end">
          <woot-button color-scheme="secondary" @click="resetFilters">
            {{ $t('BILLING.FILTERS.RESET') }}
          </woot-button>
        </div>
      </div>

      <!-- Transactions Table -->
      <div v-if="loading" class="space-y-4">
        <div v-for="i in 5" :key="i" class="animate-pulse">
          <div class="h-12 bg-slate-200 rounded" />
        </div>
      </div>

      <div v-else-if="transactions.length === 0" class="text-center py-12">
        <div class="text-slate-500">
          <svg
            class="mx-auto h-12 w-12 text-slate-400 mb-4"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
            />
          </svg>
          <p class="text-lg font-medium">
            {{ $t('BILLING.TRANSACTIONS.NO_TRANSACTIONS') }}
          </p>
          <p class="text-sm">{{ $t('BILLING.TRANSACTIONS.EMPTY_MESSAGE') }}</p>
        </div>
      </div>

      <div v-else class="overflow-x-auto">
        <table class="w-full">
          <thead>
            <tr class="border-b border-slate-200">
              <th class="text-left py-3 text-sm font-medium text-slate-600">
                {{ $t('BILLING.TRANSACTIONS.DATE') }}
              </th>
              <th class="text-left py-3 text-sm font-medium text-slate-600">
                {{ $t('BILLING.TRANSACTIONS.TRANSACTION_ID') }}
              </th>
              <th class="text-left py-3 text-sm font-medium text-slate-600">
                {{ $t('BILLING.TRANSACTIONS.PLAN') }}
              </th>
              <th class="text-left py-3 text-sm font-medium text-slate-600">
                {{ $t('BILLING.TRANSACTIONS.AMOUNT') }}
              </th>
              <th class="text-left py-3 text-sm font-medium text-slate-600">
                {{ $t('BILLING.TRANSACTIONS.PAYMENT_METHOD') }}
              </th>
              <th class="text-left py-3 text-sm font-medium text-slate-600">
                {{ $t('BILLING.TRANSACTIONS.STATUS') }}
              </th>
              <th class="text-left py-3 text-sm font-medium text-slate-600">
                {{ $t('BILLING.TRANSACTIONS.ACTIONS') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="transaction in transactions"
              :key="transaction.id"
              class="border-b border-slate-100 hover:bg-slate-50"
            >
              <td class="py-4 text-sm text-slate-900">
                {{ formatDate(transaction.created_at) }}
              </td>
              <td class="py-4 text-sm text-slate-600 font-mono">
                {{ $t('BILLING.TRANSACTION_DETAILS.ID_PREFIX')
                }}{{ transaction.id }}
              </td>
              <td class="py-4 text-sm text-slate-900">
                {{ transaction.billing_plan?.name || '-' }}
              </td>
              <td class="py-4 text-sm text-slate-900 font-semibold">
                {{ $t('BILLING.CURRENCY_SYMBOL') }}{{ transaction.amount }}
              </td>
              <td class="py-4 text-sm text-slate-600">
                {{ transaction.payment_method || 'Online Payment' }}
              </td>
              <td class="py-4">
                <woot-badge
                  :color="getStatusColor(transaction.status)"
                  :text="getStatusText(transaction.status)"
                />
              </td>
              <td class="py-4">
                <div class="flex gap-2">
                  <woot-button
                    v-if="transaction.status === 'successful'"
                    size="small"
                    color-scheme="secondary"
                    :loading="downloadingInvoices.includes(transaction.id)"
                    @click="downloadInvoice(transaction.id)"
                  >
                    {{ $t('BILLING.BUTTONS.DOWNLOAD_INVOICE') }}
                  </woot-button>

                  <woot-button
                    size="small"
                    color-scheme="secondary"
                    @click="viewTransactionDetails(transaction)"
                  >
                    {{ $t('BILLING.BUTTONS.VIEW_DETAILS') }}
                  </woot-button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Pagination -->
      <div v-if="pagination.total_pages > 1" class="mt-6 flex justify-center">
        <nav class="flex items-center space-x-2">
          <woot-button
            size="small"
            color-scheme="secondary"
            :disabled="pagination.current_page === 1"
            @click="changePage(pagination.current_page - 1)"
          >
            {{ $t('BILLING.PAGINATION.PREVIOUS') }}
          </woot-button>

          <span class="px-3 py-1 text-sm text-slate-600">
            {{
              $t('BILLING.PAGINATION.PAGE_INFO', {
                current: pagination.current_page,
                total: pagination.total_pages,
              })
            }}
          </span>

          <woot-button
            size="small"
            color-scheme="secondary"
            :disabled="pagination.current_page === pagination.total_pages"
            @click="changePage(pagination.current_page + 1)"
          >
            {{ $t('BILLING.PAGINATION.NEXT') }}
          </woot-button>
        </nav>
      </div>
    </div>

    <div class="flex justify-end gap-2 p-6 border-t border-slate-200">
      <woot-button color-scheme="secondary" @click="onClose">
        {{ $t('GENERAL_SETTINGS.FORM.CANCEL') }}
      </woot-button>
    </div>

    <!-- Transaction Details Modal -->
    <TransactionDetailsModal
      v-if="selectedTransaction"
      :show="!!selectedTransaction"
      :transaction="selectedTransaction"
      @close="selectedTransaction = null"
    />
  </woot-modal>
</template>
