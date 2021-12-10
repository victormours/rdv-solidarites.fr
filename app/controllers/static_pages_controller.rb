# frozen_string_literal: true

class StaticPagesController < ApplicationController
  helper_method :current_organisation

  def mds; end

  def accessibility; end

  def contact; end

  def templates
    render layout: false
  end

  def template_usager
    render layout: "application"
  end

  def template_agent
    render layout: "application_agent"
  end

  def template_configuration
    render layout: "application_agent_departement"
  end

  def current_organisation
    Organisation.all.sample(1).first
  end
end
