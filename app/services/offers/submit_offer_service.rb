module Offers
  class SubmitOfferService
    include OrderDetails
    attr_reader :offer
    def initialize(offer)
      @offer = offer
      @order = offer.order
    end

    def process!
      pre_process!

      offer.update!(submitted_at: Time.now.utc)
      offer.order.line_items.first.update!(sales_tax_cents: offer.tax_total_cents, should_remit_sales_tax: offer.should_remit_sales_tax)
      offer.order.update!(last_offer: offer, shipping_total_cents: offer.shipping_total_cents, tax_total_cents: offer.tax_total_cents)
      OrderTotalUpdaterService.new(offer.order, @partner[:effective_commission_rate]).update_totals!
    end

    private

    def pre_process!
      assert_submit!
      OrderValidator.validate_commission_rate!(partner)
    end

    def assert_submit!
      raise Errors::ValidationError, :invalid_offer if @offer.submitted?
    end
  end
end
