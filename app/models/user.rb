class User < ActiveRecord::Base

  # Connects this user object to Blacklights Bookmarks. 
  include Blacklight::User
  # Connects this user object to Hydra behaviors. 
  include Hydra::User
  # Connects this user object to Sufia behaviors. 
  include Sufia::User
 
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  # Setup accessible (or protected) attributes for your model
  #attr_accessible :email, :password, :password_confirmation, :remember_me
  # attr_accessible :title, :body

  # Method added by Blacklight; Blacklight uses #to_s on your
  # user class to get a user-displayable login/identifier for
  # the account. 
  def to_s
    email
  end
  
  # Returns true if user has permission to act as a reviewer
  def reviewer?
    # self.groups.include?("reviewer")
    self.groupsarray.include?("reviewer")
  end
  
  # Override this when integrating with Oxford AuthN
  def groups
    RoleMapper.roles(user_key)
  end
  
  # NOTE: This was a hack to deal with the fact the the .groups method (above) wasn't overriding the implementation from Sufia
  def groupsarray
    RoleMapper.roles(user_key)
  end
end
