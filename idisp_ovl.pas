{   Routines for managing the overlay graphics.
}
module idisp_ovl;
define ovl_init;
define ovl_open;
define ovl_close;
define ovl_draw;
%include 'idisp.ins.pas';

const
  def_red = 1.0;                       {default color}
  def_grn = 0.4;
  def_blu = 0.4;
  def_wid = (2.0 / 1080.0) * 3.0;      {default vector width, 3 pixels at 1080 dim}

var
  def_color: displ_color_t;            {global default color}
  def_vparm: rend_vect_parms_t;        {global default vector drawing parameters}
  def_tparm: rend_text_parms_t;        {global default text drawing parameters}
{
********************************************************************************
*
*   Subroutine OVL_INIT
*
*   One-time call to initialize the state managed by this module.  RENDlib must
*   already be initialized.
}
procedure ovl_init;                    {one-time initialization of OVL_INT module}
  val_param;

begin
  rend_set.enter_rend^;                {into graphic mode}

  def_color.red := def_red;            {set global default color}
  def_color.grn := def_grn;
  def_color.blu := def_blu;
  def_color.opac := 1.0;

  rend_get.vect_parms^ (def_vparm);    {make sure all vect parm fields set}
  def_vparm.width := def_wid;
  def_vparm.poly_level := rend_space_2dcl_k; {vectors to polygons in 2D space}
  def_vparm.start_style.style := rend_end_style_circ_k;
  def_vparm.start_style.nsides := 4;
  def_vparm.end_style.style := rend_end_style_circ_k;
  def_vparm.end_style.nsides := 4;
  def_vparm.subpixel := true;

  rend_get.text_parms^ (def_tparm);    {make sure all text parm fields set}

  rend_set.exit_rend^;                 {pop back out of graphics mode}
  end;
{
********************************************************************************
*
*   Subroutine OVL_OPEN
*
*   Initialize the overlay data for the current image.
}
procedure ovl_open;                    {init overlay for current image}
  val_param;

begin
  displ_list_new (                     {create the display list}
    util_top_mem_context, ovl_list);
  {
  *   Set the global default drawing parameters for the overlay.
  }
  ovl_list.rend.color_p := addr(def_color);
  ovl_list.rend.vect_parm_p := addr(def_vparm);
  ovl_list.rend.text_parm_p := addr(def_tparm);
  end;
{
********************************************************************************
*
*   Subroutine OVL_CLOSE
*
*   Close the overlay data for the current image, deallocate resources.
}
procedure ovl_close;                   {close and deallocate curr image overlay}
  val_param;

begin
  displ_list_del (ovl_list);
  end;
{
********************************************************************************
*
*   Subroutine OVL_DRAW
*
*   Draw all the overlay graphics.
}
procedure ovl_draw;                    {draw all the overlay graphics}
  val_param;

begin
  displ_draw_list (ovl_list);          {draw the whole display list contents}
  end;
