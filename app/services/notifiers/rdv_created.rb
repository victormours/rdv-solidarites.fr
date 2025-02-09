# frozen_string_literal: true

class Notifiers::RdvCreated < Notifiers::RdvBase
  protected

  def rdvs_users_to_notify
    @rdv.rdvs_users.where(send_lifecycle_notifications: true)
  end

  def notify_user_by_mail(user)
    Users::RdvMailer.rdv_created(@rdv.payload(:create, user), user).deliver_later
    @rdv.events.create!(event_type: RdvEvent::TYPE_NOTIFICATION_MAIL, event_name: :created)
  end

  def notify_user_by_sms(user)
    Users::RdvSms.rdv_created(@rdv, user).deliver_later
    @rdv.events.create!(event_type: RdvEvent::TYPE_NOTIFICATION_SMS, event_name: :created)
  end

  def notify_agent(agent)
    Agents::RdvMailer.rdv_created(@rdv.payload(:create, agent), agent).deliver_later
  end
end
