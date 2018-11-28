class CommitOrderService
  def self.call!(order, order_state_action:, by: nil)
    new(order, order_state_action, by).process!
  end

  attr_accessor :order, :credit_card, :merchant_account, :partner
  def initialize(order, order_state_action, by)
    @order = order
    @order_state_action = order_state_action
    @by = by
    @credit_card = nil
    @merchant_account = nil
    @partner = nil
    @transaction = nil
    @deducted_inventory = []
  end

  def process!
    pre_process!
    commit_order!
    post_process!
    @order
  rescue Errors::ValidationError, Errors::ProcessingError => e
    undeduct_inventory
    raise e
  ensure
    if @transaction.present?
      @order.transactions << @transaction
      notify_failed_charge if @transaction.failed?
    end
  end
  
  protected

  def commit_order!
    @order.send(@order_state_action) do
      deduct_inventory
      process_payment
    end
  end

  def undeduct_inventory
    @deducted_inventory.each { |li| GravityService.undeduct_inventory(li) }
    @deducted_inventory = []
  end

  def deduct_inventory
      # Try holding artwork and deduct inventory
      @order.line_items.each do |li|
        GravityService.deduct_inventory(li)
        @deducted_inventory << li
      end
  end
  
  def process_payment
  end

  def pre_process!
    @order.line_items.map do |li|
      artwork = GravityService.get_artwork(li[:artwork_id])
      Exchange.dogstatsd.increment 'submit.artwork_version_mismatch'
      raise Errors::ProcessingError, :artwork_version_mismatch if artwork[:current_version_id] != li[:artwork_version_id]
    end
    @credit_card = GravityService.get_credit_card(@order.credit_card_id)
    assert_credit_card!
    @partner = GravityService.fetch_partner(@order.seller_id)
    raise Errors::ValidationError.new(:missing_commission_rate, partner_id: @partner[:id]) if @partner[:effective_commission_rate].blank?

    @merchant_account = GravityService.get_merchant_account(@order.seller_id)
    OrderTotalUpdaterService.new(@order, @partner[:effective_commission_rate]).update_totals!
  end

  def post_process!
    @order.update!(external_charge_id: @transaction.external_id)
  end

  def notify_failed_charge
    PostTransactionNotificationJob.perform_later(@transaction.id, TransactionEvent::CREATED, @by)
  end

  def construct_charge_params(capture:)
    {
      credit_card: @credit_card,
      buyer_amount: @order.buyer_total_cents,
      merchant_account: @merchant_account,
      seller_amount: @order.seller_total_cents,
      currency_code: @order.currency_code,
      metadata: charge_metadata,
      description: charge_description,
      capture: capture
    }
  end

  def assert_credit_card!
    raise Errors::ValidationError.new(:credit_card_missing_external_id, credit_card_id: @credit_card[:id]) if @credit_card[:external_id].blank?
    raise Errors::ValidationError.new(:credit_card_missing_customer, credit_card_id: @credit_card[:id]) if @credit_card.dig(:customer_account, :external_id).blank?
    raise Errors::ValidationError.new(:credit_card_deactivated, credit_card_id: @credit_card[:id]) unless @credit_card[:deactivated_at].nil?
  end

  def charge_description
    "#{(@partner[:name] || '').parameterize[0...12].upcase} via Artsy"
  end

  def charge_metadata
    {
      exchange_order_id: @order.id,
      buyer_id: @order.buyer_id,
      buyer_type: @order.buyer_type,
      seller_id: @order.seller_id,
      seller_type: @order.seller_type,
      type: @order.auction_seller? ? 'auction-bn' : 'bn-mo'
    }
  end
end
