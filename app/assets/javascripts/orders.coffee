showOrderDialog = (orderId) ->
  $.ajax
    url: "/orders/#{orderId}/show_order_dialog"
    type: "POST"
    dataType: "json"
    success: ({order_id, user, organization, order_date, status, order_details}) ->
      $("#order_id").text order_id
      $("#user_name").text user.name
      $("#email").text user.email
      $("#phone_number").text user.phone_number
      $("#organization_name").text organization.name
      $("#county").text organization.county
      $("#address").text user.address
      $("#date_received").text order_date
      $("#status").text status
      $("#edit_order_button").attr "href", "/orders/#{order_id}/edit"
      orderDetails = JSON.parse(order_details)
      html = []
      html.push("<tr><td>#{item.description}</td><td>#{item.quantity}</td></tr>") for item in orderDetails
      $("#order-details").html html.join("")
      $("#order_details_modal").modal()
    error: (jqXHR, textStatus, errorThrown) ->
      alert "Error occurred"

expose "orderRowClicked", (event, row, element) ->
  event.stopPropagation()
  orderId = row.data "order-id"
  showOrderDialog orderId

populateCategories = (element) ->
  for {id, description} in data.categories
    element.append """<option value="#{id}">#{description}</option>"""

populateItems = (category_id, element) ->
  id = parseInt category_id
  for category in data.categories
    if category.id is id
      currentCategory = category
  element.empty()
  element.append """<option value="">Select an item...</option>"""
  for {id, description, current_quantity, requested_quantity} in currentCategory.items
    element.append """<option value="#{id}" data-current-quantity="#{current_quantity}" data-requested-quantity="#{requested_quantity}">#{description}</option>"""

populateQuantity = (current_quantity, requested_quantity, element) ->
  available_quantity = parseInt(current_quantity) - parseInt(requested_quantity)
  element.val("")
  element.attr("placeholder", available_quantity + " available")

populateQuantity = (category_id, item_id, element) ->
  cat_id = parseInt category_id
  itm_id = parseInt item_id
  qty_available = 0
  for category in data.categories
    if category.id is cat_id
      console.log("cat_id = " + cat_id)
      for item in category.items
        if item.id is itm_id
          console.log("itm_id = " + itm_id)
          qty_available = item.current_quantity - item.requested_quantity
  console.log(qty_available)
  element.change ->


addNewOrderRow = ->
  currentNumRows = $("#new-order-table tbody").find("tr").length
  newRow = $("""
    <tr class="new-order-row">
      <td>
        <select class="category form-control row-#{currentNumRows}">
          <option value="">Select a category...</option>
        </select>
      </td>
      <td>
        <select class="item form-control row-#{currentNumRows}">
          <option value="">Select an item...</option>
        </select>
      </td>
      <td>
        <input class="quantity form-control row-#{currentNumRows}" type="number" min="1" max="0" />
      </td>
    </tr>
  """)
  category = newRow.find ".category"
  populateCategories category
  $("#new-order-table tbody").append newRow

$(document).on "click", ".add-item", (event) ->
  event.preventDefault()
  event.stopPropagation()
  $("#add_inventory_modal").modal("show")

$(document).on "click", "#add-item-row", (event) ->
  event.preventDefault()
  addNewOrderRow()

$(document).on "change", ".new-order-row .category", ->
  item_element = $(@).parents(".new-order-row").find ".item"
  populateItems $(@).val(), item_element

$(document).on "change", ".new-order-row .item", ->
# <<<<<<< Updated upstream
  # quantity_element = $(@).parents(".new-order-row").find ".quantity"
  # selected = $(@).find('option:selected')
  # populateQuantity selected.data("current-quantity"), selected.data("requested-quantity"), quantity_element
# =======
  category_element = $(@).parents(".new-order-row").find ".category"
  qty_element = $(@).parents(".new-order-row").find ".quantity"
  populateQuantity category_element.val(), $(@).val(), qty_element
# >>>>>>> Stashed changes

$(document).on "page:change", ->
  addNewOrderRow() if $("#new-order-table").length > 0
