# frozen_string_literal: true

class NextAvailabilityService
  def self.find(motif, lieu, from, agents)
    available_creneau = nil

    from.step(from + 6.months, 7).find do |date|
      # NOTE: LOOP 2 loop here for ~ 27 weeks
      # We break out of the loop once we find a creneau.
      #

      creneaux = SlotBuilder.available_slots(motif, lieu, date..(date + 7.days), OffDays.all_in_date_range(date..(date + 7.days)), agents)
      # NOTE: We build the whole list of creneaux of the week just to return the first one.
      available_creneau = creneaux.min_by(&:starts_at) if creneaux.any?
    end
    available_creneau
  end
end
