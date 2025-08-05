<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import BillingAPI from 'dashboard/api/billing';
import UpgradePlansModal from './components/UpgradePlansModal.vue';
import TransactionHistoryModal from './components/TransactionHistoryModal.vue';

const { t } = useI18n();
const { showAlert } = useAlert();

const loading = ref(false);
const currentPlan = ref(null);
const subscription = ref(null);
const recentTransactions = ref([]);
const showUpgradePlans = ref(false);
const showTransactionHistory = ref(false);

const messagesRemaining = computed(() => {
  if (!currentPlan.value || !subscription.value) return 0;
  return Math.max(
    0,
    currentPlan.value.message_limit - subscription.value.messages_used
  );
});

const usagePercentage = computed(() => {
  if (!currentPlan.value || !subscription.value) return 0;
  return (
    (subscription.value.messages_used / currentPlan.value.message_limit) * 100
  );
});

const getStatusColor = status => {
  const colors = {
    active: 'success',
    suspended: 'warning',
    cancelled: 'error',
    pending: 'secondary',
    successful: 'success',
    failed: 'error',
  };
  return colors[status] || 'secondary';
};

const getStatusText = status => {
  if (!status) return '';
  const statusKey = `BILLING.STATUS.${status.toUpperCase()}`;
  return t(statusKey);
};

const getUsageBarColor = percentage => {
  if (percentage >= 100) return 'bg-red-500';
  if (percentage >= 80) return 'bg-yellow-500';
  return 'bg-green-500';
};

const getUsageAlertMessage = percentage => {
  if (percentage >= 100) return t('BILLING.ALERTS.LIMIT_EXCEEDED');
  if (percentage >= 80) return t('BILLING.ALERTS.NEAR_LIMIT');
  return '';
};

const formatNumber = number => {
  return new Intl.NumberFormat().format(number);
};

const formatDate = dateString => {
  return new Date(dateString).toLocaleDateString();
};

const fetchBillingData = async () => {
  loading.value = true;
  try {
    const [billingData, transactionsData] = await Promise.all([
      BillingAPI.show(),
      BillingAPI.getTransactions({ limit: 5 }),
    ]);

    currentPlan.value = billingData.current_plan;
    subscription.value = billingData.subscription;
    recentTransactions.value = transactionsData.transactions || [];
  } catch (error) {
    showAlert(error.message || 'Failed to load billing data');
  } finally {
    loading.value = false;
  }
};

const refreshData = () => {
  fetchBillingData();
};

const handlePlanUpgrade = async planId => {
  try {
    const response = await BillingAPI.upgradePlan({ plan_id: planId });
    if (response.payment_url) {
      window.open(response.payment_url, '_blank');
    }
    showAlert(t('BILLING.PAYMENT.PAYMENT_SUCCESS'), 'success');
    showUpgradePlans.value = false;
    await fetchBillingData();
  } catch (error) {
    showAlert(error.message || t('BILLING.PAYMENT.PAYMENT_FAILED'));
  }
};

const downloadInvoice = async transactionId => {
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
  }
};

onMounted(() => {
  fetchBillingData();
});
</script>

<template>
  <div class="flex flex-col h-full overflow-hidden">
    <woot-page-header
      :header-title="$t('BILLING.HEADER')"
      :header-content="$t('BILLING.DESCRIPTION')"
    />

    <div class="flex-1 overflow-auto p-4 space-y-6">
      <!-- Current Plan Section -->
      <div class="bg-white rounded-lg shadow-sm border border-slate-200 p-6">
        <h3 class="text-lg font-semibold text-slate-800 mb-4">
          {{ $t('BILLING.CURRENT_PLAN.TITLE') }}
        </h3>

        <div v-if="loading" class="animate-pulse">
          <div class="h-4 bg-slate-200 rounded w-1/4 mb-2" />
          <div class="h-4 bg-slate-200 rounded w-1/2 mb-2" />
          <div class="h-4 bg-slate-200 rounded w-1/3" />
        </div>

        <div
          v-else-if="currentPlan"
          class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4"
        >
          <div>
            <label class="text-sm font-medium text-slate-600">
              {{ $t('BILLING.CURRENT_PLAN.PLAN_NAME') }}
            </label>
            <p class="text-lg font-semibold text-slate-900">
              {{ currentPlan.name }}
            </p>
          </div>
          <div>
            <label class="text-sm font-medium text-slate-600">
              {{ $t('BILLING.CURRENT_PLAN.MONTHLY_LIMIT') }}
            </label>
            <p class="text-lg font-semibold text-slate-900">
              {{ formatNumber(currentPlan.message_limit) }}
              {{ $t('BILLING.PLANS.MESSAGES_PER_MONTH') }}
            </p>
          </div>
          <div>
            <label class="text-sm font-medium text-slate-600">
              {{ $t('BILLING.CURRENT_PLAN.PRICE') }}
            </label>
            <p class="text-lg font-semibold text-slate-900">
              {{ $t('BILLING.CURRENCY_SYMBOL') }}{{ currentPlan.price }}
            </p>
          </div>
          <div>
            <label class="text-sm font-medium text-slate-600">
              {{ $t('BILLING.CURRENT_PLAN.STATUS') }}
            </label>
            <woot-badge
              :color="getStatusColor(subscription?.status)"
              :text="getStatusText(subscription?.status)"
            />
          </div>
        </div>
      </div>

      <!-- Usage Section -->
      <div class="bg-white rounded-lg shadow-sm border border-slate-200 p-6">
        <h3 class="text-lg font-semibold text-slate-800 mb-4">
          {{ $t('BILLING.USAGE.TITLE') }}
        </h3>

        <div v-if="loading" class="animate-pulse">
          <div class="h-4 bg-slate-200 rounded w-full mb-4" />
          <div class="h-8 bg-slate-200 rounded w-full" />
        </div>

        <div v-else-if="subscription" class="space-y-4">
          <div class="flex justify-between items-center">
            <span class="text-sm font-medium text-slate-600">
              {{ $t('BILLING.USAGE.MESSAGES_USED')
              }}{{ $t('BILLING.SEPARATOR') }}
              {{ formatNumber(subscription.messages_used) }}
            </span>
            <span class="text-sm font-medium text-slate-600">
              {{ $t('BILLING.USAGE.MESSAGES_REMAINING')
              }}{{ $t('BILLING.SEPARATOR') }}
              {{ formatNumber(messagesRemaining) }}
            </span>
          </div>

          <!-- Progress Bar -->
          <div class="w-full bg-slate-200 rounded-full h-3">
            <div
              class="h-3 rounded-full transition-all duration-300"
              :class="getUsageBarColor(usagePercentage)"
              :style="{ width: `${Math.min(usagePercentage, 100)}%` }"
            />
          </div>

          <div class="flex justify-between items-center text-sm text-slate-600">
            <span
              >{{ usagePercentage.toFixed(1)
              }}{{ $t('BILLING.PERCENTAGE_SYMBOL') }}
              {{ $t('BILLING.USAGE.USAGE_PERCENTAGE') }}</span
            >
            <span
              >{{ $t('BILLING.USAGE.RESET_DATE')
              }}{{ $t('BILLING.SEPARATOR') }}
              {{ formatDate(subscription.next_reset_date) }}</span
            >
          </div>

          <!-- Usage Alerts -->
          <div v-if="usagePercentage >= 80" class="mt-4">
            <woot-alert
              :type="usagePercentage >= 100 ? 'error' : 'warning'"
              :message="getUsageAlertMessage(usagePercentage)"
            />
          </div>
        </div>
      </div>

      <!-- Quick Actions -->
      <div class="bg-white rounded-lg shadow-sm border border-slate-200 p-6">
        <div class="flex flex-wrap gap-4">
          <woot-button color-scheme="primary" @click="showUpgradePlans = true">
            {{ $t('BILLING.BUTTONS.UPGRADE_PLAN') }}
          </woot-button>

          <woot-button
            color-scheme="secondary"
            @click="showTransactionHistory = true"
          >
            {{ $t('BILLING.TRANSACTIONS.TITLE') }}
          </woot-button>

          <woot-button
            color-scheme="secondary"
            :loading="loading"
            @click="refreshData"
          >
            {{ $t('BILLING.BUTTONS.REFRESH') }}
          </woot-button>
        </div>
      </div>

      <!-- Recent Transactions -->
      <div class="bg-white rounded-lg shadow-sm border border-slate-200 p-6">
        <h3 class="text-lg font-semibold text-slate-800 mb-4">
          {{ $t('BILLING.TRANSACTIONS.TITLE') }}
        </h3>

        <div
          v-if="recentTransactions.length === 0"
          class="text-center py-8 text-slate-500"
        >
          {{ $t('BILLING.TRANSACTIONS.NO_TRANSACTIONS') }}
        </div>

        <div v-else class="overflow-x-auto">
          <table class="w-full">
            <thead>
              <tr class="border-b border-slate-200">
                <th class="text-left py-2 text-sm font-medium text-slate-600">
                  {{ $t('BILLING.TRANSACTIONS.DATE') }}
                </th>
                <th class="text-left py-2 text-sm font-medium text-slate-600">
                  {{ $t('BILLING.TRANSACTIONS.PLAN') }}
                </th>
                <th class="text-left py-2 text-sm font-medium text-slate-600">
                  {{ $t('BILLING.TRANSACTIONS.AMOUNT') }}
                </th>
                <th class="text-left py-2 text-sm font-medium text-slate-600">
                  {{ $t('BILLING.TRANSACTIONS.STATUS') }}
                </th>
                <th class="text-left py-2 text-sm font-medium text-slate-600">
                  {{ $t('BILLING.TRANSACTIONS.ACTIONS') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="transaction in recentTransactions.slice(0, 5)"
                :key="transaction.id"
                class="border-b border-slate-100"
              >
                <td class="py-3 text-sm text-slate-900">
                  {{ formatDate(transaction.created_at) }}
                </td>
                <td class="py-3 text-sm text-slate-900">
                  {{ transaction.billing_plan?.name || '-' }}
                </td>
                <td class="py-3 text-sm text-slate-900">
                  {{ $t('BILLING.CURRENCY_SYMBOL') }}{{ transaction.amount }}
                </td>
                <td class="py-3">
                  <woot-badge
                    :color="getStatusColor(transaction.status)"
                    :text="getStatusText(transaction.status)"
                  />
                </td>
                <td class="py-3">
                  <woot-button
                    v-if="transaction.status === 'successful'"
                    size="small"
                    color-scheme="secondary"
                    @click="downloadInvoice(transaction.id)"
                  >
                    {{ $t('BILLING.BUTTONS.DOWNLOAD_INVOICE') }}
                  </woot-button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- Upgrade Plans Modal -->
    <UpgradePlansModal
      v-if="showUpgradePlans"
      :show="showUpgradePlans"
      :current-plan="currentPlan"
      @close="showUpgradePlans = false"
      @plan-selected="handlePlanUpgrade"
    />

    <!-- Transaction History Modal -->
    <TransactionHistoryModal
      v-if="showTransactionHistory"
      :show="showTransactionHistory"
      @close="showTransactionHistory = false"
    />
  </div>
</template>
