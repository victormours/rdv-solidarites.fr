# frozen_string_literal: true

class Notifiers::RdvCancelled < Notifiers::RdvBase
  protected

  def rdvs_users_to_notify
    @rdv.rdvs_users.where(send_lifecycle_notifications: true)
  end

  def notify_user_by_mail(user)
    # Only send sms for excused cancellations (not for no-show)
    return unless @rdv.status.in? %w[excused revoked]

    Users::RdvMailer.rdv_cancelled(@rdv.payload(:destroy, user), user).deliver_later

    status_to_event_name = {
      "excused" => :cancelled_by_user,
      "revoked" => :cancelled_by_agent
    }
    event_name = status_to_event_name[@rdv.status]
    @rdv.events.create!(event_type: RdvEvent::TYPE_NOTIFICATION_MAIL, event_name: event_name)
  end

  def notify_user_by_sms(user)
    # Only send sms for excused cancellations by an Agent (not for no-show, not for self-cancellation)
    return unless @author.is_a? Agent
    return unless @rdv.status.in? %w[excused revoked]

    Users::RdvSms.rdv_cancelled(@rdv, user).deliver_later
    @rdv.events.create!(event_type: RdvEvent::TYPE_NOTIFICATION_SMS, event_name: :cancelled_by_agent)
  end

  def notify_agent(agent)
    Agents::RdvMailer.rdv_cancelled(@rdv.payload(:destroy, agent), agent, @author).deliver_later
  end
end
