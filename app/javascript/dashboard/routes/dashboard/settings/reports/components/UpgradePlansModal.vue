<script setup>
import { ref, onMounted } from 'vue';
import { useAlert } from 'dashboard/composables';
import BillingAPI from 'dashboard/api/billing';

const props = defineProps({
  show: {
    type: Boolean,
    required: true,
  },
  currentPlan: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['close', 'planSelected']);

const { showAlert } = useAlert();

const loading = ref(false);
const processing = ref(false);
const availablePlans = ref([]);
const selectedPlan = ref(null);
const error = ref('');

const formatNumber = number => {
  return new Intl.NumberFormat().format(number);
};

const selectPlan = plan => {
  if (plan.id !== props.currentPlan?.id) {
    selectedPlan.value = plan;
  }
};

const fetchPlans = async () => {
  loading.value = true;
  error.value = '';

  try {
    const response = await BillingAPI.getPlans();
    availablePlans.value = response.plans || [];
  } catch (err) {
    error.value = err.message || 'Failed to load plans';
    showAlert(error.value);
  } finally {
    loading.value = false;
  }
};

const handleUpgrade = async () => {
  if (!selectedPlan.value) return;

  processing.value = true;

  try {
    emit('planSelected', selectedPlan.value.id);
  } catch (err) {
    showAlert(err.message || 'Failed to upgrade plan');
  } finally {
    processing.value = false;
  }
};

const onClose = () => {
  emit('close');
};

onMounted(() => {
  fetchPlans();
});
</script>

<template>
  <woot-modal :show="show" :on-close="onClose">
    <woot-modal-header
      :header-title="$t('BILLING.PLANS.TITLE')"
      :header-content="$t('BILLING.PAYMENT.SELECT_PLAN')"
    />

    <div class="p-6">
      <div v-if="loading" class="space-y-4">
        <div v-for="i in 3" :key="i" class="animate-pulse">
          <div class="h-32 bg-slate-200 rounded-lg" />
        </div>
      </div>

      <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <div
          v-for="plan in availablePlans"
          :key="plan.id"
          class="border rounded-lg p-4 hover:shadow-md transition-shadow cursor-pointer"
          :class="{
            'border-blue-500 bg-blue-50': selectedPlan?.id === plan.id,
            'border-green-500 bg-green-50': currentPlan?.id === plan.id,
            'border-slate-200':
              selectedPlan?.id !== plan.id && currentPlan?.id !== plan.id,
          }"
          @click="selectPlan(plan)"
        >
          <div class="flex justify-between items-start mb-2">
            <h3 class="text-lg font-semibold text-slate-900">
              {{ plan.name }}
            </h3>
            <div v-if="currentPlan?.id === plan.id" class="text-xs">
              <woot-badge color="success" :text="$t('BILLING.PLANS.CURRENT')" />
            </div>
          </div>

          <div class="space-y-2">
            <div class="text-2xl font-bold text-slate-900">
              {{ $t('BILLING.CURRENCY_SYMBOL') }}{{ plan.price }}
              <span class="text-sm font-normal text-slate-600">{{
                $t('BILLING.PLANS.PER_MONTH')
              }}</span>
            </div>

            <div class="text-sm text-slate-600">
              {{ formatNumber(plan.message_limit) }}
              {{ $t('BILLING.PLANS.MESSAGES_PER_MONTH') }}
            </div>

            <div v-if="plan.description" class="text-sm text-slate-600">
              {{ plan.description }}
            </div>

            <div v-if="plan.features && plan.features.length > 0" class="mt-3">
              <p class="text-sm font-medium text-slate-700 mb-1">
                {{ $t('BILLING.PLANS.FEATURES') }}{{ $t('BILLING.SEPARATOR') }}
              </p>
              <ul class="text-xs text-slate-600 space-y-1">
                <li
                  v-for="feature in plan.features"
                  :key="feature"
                  class="flex items-center"
                >
                  <svg
                    class="w-3 h-3 text-green-500 mr-1"
                    fill="currentColor"
                    viewBox="0 0 20 20"
                  >
                    <path
                      fill-rule="evenodd"
                      d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                      clip-rule="evenodd"
                    />
                  </svg>
                  {{ feature }}
                </li>
              </ul>
            </div>
          </div>
        </div>
      </div>

      <div v-if="error" class="mt-4">
        <woot-alert type="error" :message="error" />
      </div>
    </div>

    <div class="flex justify-end gap-2 p-6 border-t border-slate-200">
      <woot-button color-scheme="secondary" @click="onClose">
        {{ $t('GENERAL_SETTINGS.FORM.CANCEL') }}
      </woot-button>

      <woot-button
        color-scheme="primary"
        :disabled="
          !selectedPlan || selectedPlan.id === currentPlan?.id || processing
        "
        :loading="processing"
        @click="handleUpgrade"
      >
        {{
          selectedPlan?.price > 0
            ? $t('BILLING.BUTTONS.MAKE_PAYMENT')
            : $t('BILLING.PLANS.UPGRADE')
        }}
      </woot-button>
    </div>
  </woot-modal>
</template>
