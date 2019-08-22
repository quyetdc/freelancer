class UsersController < ApplicationController
  before_action :authenticate_user!

  def dashboard
    if params[:category]
      @gigs = current_user.gigs.joins(:category).where(categories: { name: params[:category] }).all
    else
      @gigs = current_user.gigs
    end

  end

  def show
    @user = User.find(params[:id])
    @reviews = Review.where(seller_id: params[:id]).order(created_at: :asc)
  end

  def update
    @user = current_user
    if @user.update(current_user_params)
      flash[:notice] = "Saved..."
    else
      flash[:alert] = "Cannot update..."
    end

    redirect_to dashboard_path
  end

  def callback_phone
    path_access_token = "https://graph.accountkit.com/v1.1/access_token?" +
                         "grant_type=authorization_code" +
                         "&code=#{params[:code]}" +
                         "&access_token=AA|#{Rails.application.credentials.facebook_api}|#{Rails.application.credentials.facebook_kit_secret}"

    response = Net::HTTP.get(URI.parse(path_access_token))
    response = JSON.parse(response)

    if response['access_token']
      path_get_data = "https://graph.accountkit.com/v1.1/me?access_token=#{response['access_token']}"


      response = Net::HTTP.get(URI.parse(path_get_data))
      response = JSON.parse(response)

      if response['phone']['number']
        current_user.update(phone: response['phone']['number'])

        return render json: { success: true }
      end
    end

    return render json: { success: false }
  end

  def update_payment
    unless current_user.stripe_id
      customer = Stripe::Customer.create(
        email: current_user.email,
        source: params[:stripeToken]
      )
    else
      customer = Stripe::Customer.update(
        current_user.stripe_id,
        source: params[:stripeToken]
      )
    end

    if current_user.update(
      stripe_id: customer.id,
      stripe_last_4: customer.sources.data.first['last4']
    )

      flash[:notice] = "New card is saved"
    else
      flash[:alert] = "Invalid card"
    end

    redirect_to request.referrer

  rescue Stripe::CardError => e
    flash[:alert] = e.message
    redirect_to request.referrer
  end

  private

  def current_user_params
    params.require(:user).permit(:from, :about, :status, :language, :avatar)
  end
end
