# frozen_string_literal: true

class CreneauxBuilderService < BaseService
  def initialize(motif_name, lieu, inclusive_date_range, **options)
    @motif_name = motif_name
    @lieu = lieu
    @inclusive_date_range = inclusive_date_range
    @options = options
    @for_agents = options.fetch(:for_agents, false)
    @agent_ids = options.fetch(:agent_ids, nil)
    @agent_name = options.fetch(:agent_name, false)
    @motif_location_type = options.fetch(:motif_location_type, nil)
    @plages_ouvertures = options[:plages_ouvertures]
    @service = options[:service]
  end

  def perform
    # NOTE: LOOP 2/3. We flatten many loops here.
    # * plage_ouvertures
    #   * creneaux, which are actually built on
    #   * motifs
    #     * creneaux, which are actually built on
    #     * occurrences of the plage_ouverture
    creneaux = plages_ouvertures.flat_map { |po| creneaux_for_plage_ouverture(po) }
    creneaux = creneaux.select { |c| c.starts_at >= Time.zone.now }
    uniq_by = @for_agents ? ->(c) { [c.starts_at, c.agent_id] } : ->(c) { c.starts_at }
    creneaux.uniq(&uniq_by).sort_by(&:starts_at)
  end

  def plages_ouvertures # NOTE: this is cached by find_availability_service
    @plages_ouvertures ||= PlageOuverture
      .in_range(@inclusive_date_range)
      .for_lieu(@lieu)
      .not_expired
      .for_motif(@motif_name, @lieu.organisation_id)
      .includes(:agent)
      .where(({ agent_id: @agent_ids } if @agent_ids.present?))
      .where(({ motifs: { location_type: @motif_location_type } } if @motif_location_type.present?))
      .where(({ motifs: { service: @service } } if @service.present?))
  end

  private

  def motifs_for_plage_ouverture(plage_ouverture)
    # NOTE: Because things are clumsy, we’re searching by motif_name even though we’re being passed an explicit motif
    # I think This means if we have several motifs of the same name, but location_type is different, both motifs are returned.
    Rails.cache.fetch(["motif-for-po", @motif_name, @motif_location_type, @for_agents, plage_ouverture]) do
      motifs = plage_ouverture.motifs.where(name: @motif_name).active.distinct
      motifs = motifs.where(location_type: @motif_location_type) if @motif_location_type.present?
      @for_agents ? motifs : motifs.reservable_online
    end
  end

  def creneaux_for_plage_ouverture(plage_ouverture)
    motifs_for_plage_ouverture(plage_ouverture).flat_map { creneaux_for_plage_ouverture_and_motif(plage_ouverture, _1) } # loops on motifs
  end

  def creneaux_for_plage_ouverture_and_motif(plage_ouverture, motif)
    range = (@inclusive_date_range.begin)..(@inclusive_date_range.end.end_of_day)
    agent_rdvs_in_range = plage_ouverture.agent.rdvs.where(starts_at: range).not_cancelled.to_a
    agent_absences_range = plage_ouverture.agent.absences.not_expired.flat_map { _1.occurrences_for(range) }
    possible_overlaps = agent_rdvs_in_range + agent_absences_range

    # NOTE: LOOP 3/4 Let’s loop over the PO occurrences (limited to the range)
    occurrences(plage_ouverture, @inclusive_date_range).flat_map do |occurrence|
      CreneauxBuilderForDateService
        .perform_with(plage_ouverture, motif, occurrence.starts_at.to_date, @lieu, possible_overlaps, **@options)
    end
  end

  def occurrences(plage_ouverture, date_range)
    Rails.cache.fetch(["occurrence_for", plage_ouverture, date_range.begin, date_range.end]) do
      plage_ouverture.occurrences_for(date_range)
    end
  end
end
