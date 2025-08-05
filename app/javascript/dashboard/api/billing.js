/* global axios */
import ApiClient from './ApiClient';

class BillingAPI extends ApiClient {
  constructor() {
    super('billing', { accountScoped: true });
  }

  show() {
    return axios.get(this.url);
  }

  getPlans() {
    return axios.get(`${this.url}/plans`);
  }

  getTransactions(params = {}) {
    return axios.get(`${this.url}/transactions`, { params });
  }

  getUsageReport(params = {}) {
    return axios.get(`${this.url}/usage_report`, { params });
  }

  getAlerts() {
    return axios.get(`${this.url}/alerts`);
  }

  createPayment(planId) {
    return axios.post(`${this.url}/create_payment`, {
      plan_id: planId,
    });
  }

  upgradePlan(params) {
    return axios.post(`${this.url}/upgrade_plan`, params);
  }

  downloadInvoice(transactionId) {
    return axios.get(`${this.url}/transactions/${transactionId}/invoice`, {
      responseType: 'blob',
    });
  }
}

export default new BillingAPI();
