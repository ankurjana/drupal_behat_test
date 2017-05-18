Feature: Test home page

	Scenario: Existence of links 
		Given I am on "/"	  
	  Then I should see the link "Create new account"
		Then I should see the link "Request new password"