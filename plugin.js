function ThingsPlugin()
{
}

ThingsPlugin.prototype.bundleIdentifier="cx.ath.the-kenny.ThingsPlugin";
ThingsPlugin.prototype.updateView = function(todo)
{
  var unixTimeNewYear2001 = 978307200;

  var todos = todo.todos;

  if (todos.length > 0)
	{
	  var html = "<ul><li class='header'>ToDo" + 
		((todos.length==1) ? "" : "s") + " today: " +
		todos.length+"</li>";

		for (i = 0; i < todos.length; i++) {
			html += "<li class='summary"+(i == 0 ? " firstItem" : "")+(i == todos.length - 1 ? " lastItem" : "")+"'>"+todos[i].text+"</li>";

			if(todos[i].due) {
			  var date = new Date();
			  date.setTime((unixTimeNewYear2001 + parseInt(todos[i].due)) * 1000);
			  html += "<li class='location'>"+date.toLocaleDateString()+"</li>";
			} else {
			  html += "<li class='location'> </li>";
			}
		}

		html += "</ul>";
		getPluginDiv(this).className = "things";
		getPluginDiv(this).innerHTML = html;
		
	}
  else
  	getPluginDiv(this).innerHTML = "";

  return true;
}

registerPlugin(new ThingsPlugin());
