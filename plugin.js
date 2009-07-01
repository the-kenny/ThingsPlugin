function ThingsPlugin()
{
}

ThingsPlugin.prototype.bundleIdentifier="cx.ath.the-kenny.ThingsPlugin";
ThingsPlugin.prototype.updateView = function(todo)
{
  var todos = todo.todos;

  if (todos.length > 0)
	{
	  var html = "<ul><li class='header'>New ToDo" + 
		((todos.length==1) ? "" : "s") + ": " +
		todos.length+"</li>";

		for (i = 0; i < todos.length; i++) {
			html += "<li class='summary"+(i == 0 ? " firstItem" : "")+(i == todos.length - 1 ? " lastItem" : "")+"'>"+todos[i].text+"</li>";
			html += "<li class='location'>"+todos[i].due+"</li>";
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
