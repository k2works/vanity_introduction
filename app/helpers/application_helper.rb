module ApplicationHelper
  def title(value)
    unless value.nil?
      @title = "#{value} | VanityIntroduction"      
    end
  end
end
