# frozen_string_literal: true

class DuplicateUsersFinderService < BaseService
  def initialize(user, organisation = nil)
    @user = user
    @organisation = organisation
  end

  def perform
    [
      find_duplicate_based_on_email,
      find_duplicate_based_on_identity,
      find_duplicate_based_on_phone_number
    ].compact
  end

  private

  attr_reader :user, :organisation

  def find_duplicate_based_on_email
    return if user.email.blank?

    similar_user = users_in_scope.where(email: user.email).first
    return nil if similar_user.blank?

    OpenStruct.new(severity: :error, attributes: [:email], user: similar_user)
  end

  def find_duplicate_based_on_identity
    return nil unless user.birth_date.present? && user.first_name.present? && user.last_name.present?

    similar_user = users_in_scope
      .where(birth_date: user.birth_date)
      .where(User.arel_table[:first_name].matches(user.first_name))
      .where(User.arel_table[:last_name].matches(user.last_name)).first
    return nil if similar_user.blank?

    OpenStruct.new(severity: :warning, attributes: %i[first_name last_name birth_date], user: similar_user)
  end

  def find_duplicate_based_on_phone_number
    return nil if user.phone_number_formatted.blank?

    similar_user = users_in_scope
      .where(phone_number_formatted: user.phone_number_formatted)
      .first
    return if similar_user.nil?

    OpenStruct.new(severity: :warning, attributes: [:phone_number], user: similar_user)
  end

  def users_in_scope
    u = User.active.left_joins(:rdvs).group(:id).order("COUNT(rdvs.id) DESC")
    u = u.where.not(id: user.id) if user.persisted?
    u = u.merge(organisation.users) if organisation.present?
    u
  end
end
