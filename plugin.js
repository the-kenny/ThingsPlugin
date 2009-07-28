function ThingsPlugin()
{
}

ThingsPlugin.prototype.bundleIdentifier="cx.ath.the-kenny.ThingsPlugin";
ThingsPlugin.prototype.updateView = function(todo) {
  //For date calculcation
  var unixTimeNewYear2001 = 978307200;

  var todos = todo.todos;

  if (todos.length > 0) {
	var html = "<ul><li class='header'>ToDo" + 
	  ((todos.length==1) ? " " : "s ") + todo.preferences.List + ":</li>";

	for (i = 0; i < todos.length; i++) {
	  html += "<li class='summary" + (i == 0 ? " firstItem" : "")+(i == todos.length - 1 ? " lastItem" : "")+"'>" + todos[i].text + "</li>";

	  if(todos[i].due || todos[i].project) {
		html += "<li class='location'>";

		if(todos[i].project) 
		  html += "Project: " + todos[i].project + "   "; 
		
		if(todos[i].due) {
		  var date = new Date();

		  //The years are stored in seconds since the unix time at 01/01/2001
		  //We add the unix time to the due-date to get the time as "real"
		  //unix time (Seconds since 01/01/1970)
		  date.setTime((unixTimeNewYear2001 + parseInt(todos[i].due)) * 1000);
		  html += "Due: "+date.toLocaleDateString();
		}

		html += "</li>";
	  }
	}

	/*
	  for(var prop in todo)
	  html += "<li>" + prop + "</li>";
	*/

	html += "</ul>";
	getPluginDiv(this).className = "things";
	getPluginDiv(this).innerHTML = html;
		
  } else {
  	getPluginDiv(this).innerHTML = "";
  }

  return true;
}

registerPlugin(new ThingsPlugin());
