class VanityController < ApplicationController
  layout false  # exclude this if you want to use your application layout
  include Vanity::Rails::Dashboard
end
